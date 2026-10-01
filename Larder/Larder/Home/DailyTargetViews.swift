//
//  DailyTargetViews.swift
//  Larder
//
//  Created by Joshua Samuel on 9/28/26.
//

import SwiftUI

/// One of the four daily numbers.
nonisolated enum TargetKind: String, CaseIterable, Identifiable, Sendable {
    case kcal, protein, carbs, fat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kcal: "Calories"
        case .protein: "Protein"
        case .carbs: "Carbs"
        case .fat: "Fat"
        }
    }

    var emoji: String {
        switch self {
        case .kcal: "🔥"
        case .protein: "💪"
        case .carbs: "🍚"
        case .fat: "🥑"
        }
    }

    var unit: String { self == .kcal ? "kcal" : "g" }
    var spokenUnit: String { self == .kcal ? "calories" : "grams" }

    /// How much one tap of − or + moves it.
    var step: Int { self == .kcal ? 50 : 5 }

    var range: ClosedRange<Int> {
        self == .kcal ? CustomTargets.kcalRange : 0...CustomTargets.gramsLimit
    }

    var field: WritableKeyPath<CustomTargets, Int?> {
        switch self {
        case .kcal: \.kcal
        case .protein: \.protein
        case .carbs: \.carbs
        case .fat: \.fat
        }
    }

    func value(in targets: DailyTargets) -> Int {
        switch self {
        case .kcal: targets.kcal
        case .protein: targets.protein
        case .carbs: targets.carbs
        case .fat: targets.fat
        }
    }

    /// "2,250 kcal" or "140 g".
    func text(_ value: Int) -> String {
        "\(value.formatted()) \(unit)"
    }
}

/// The arithmetic behind the − and + buttons, kept apart so it can be tested.
nonisolated enum TargetStepper {
    /// One step up or down, landing on a round number and staying in range.
    static func step(_ value: Int, by direction: Int, kind: TargetKind) -> Int {
        let size = kind.step
        let rounded = direction > 0 ? (value / size + 1) * size : ((value + size - 1) / size - 1) * size
        return min(max(rounded, kind.range.lowerBound), kind.range.upperBound)
    }

    /// What to store: nil when it matches the suggestion, so the suggestion
    /// keeps following your stats.
    static func custom(_ value: Int, suggested: Int?) -> Int? {
        value == suggested ? nil : value
    }
}

/// The day's numbers as one card: calories big on top, the three macros in
/// bubbles underneath. Anything you've set yourself is in the look's color.
/// Tap any of them to change it.
struct DailyTargetCard: View {
    let targets: DailyTargets
    let custom: CustomTargets?
    let onEdit: (TargetKind) -> Void

    private func isCustom(_ kind: TargetKind) -> Bool { custom?[keyPath: kind.field] != nil }

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Button { onEdit(.kcal) } label: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(TargetKind.kcal.title)
                            .font(.headline)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer(minLength: Theme.Spacing.xs)
                        tag(for: .kcal)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                        Text(targets.kcal.formatted())
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(isCustom(.kcal) ? Theme.Palette.amber : Theme.Palette.textPrimary)
                        Text("kcal a day")
                            .font(.headline)
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.4))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label(for: .kcal))
            .accessibilityHint("Opens an editor to change it")

            HStack(spacing: Theme.Spacing.xs) {
                ForEach([TargetKind.protein, .carbs, .fat]) { kind in
                    Button { onEdit(kind) } label: {
                        VStack(spacing: 2) {
                            Text("\(kind.value(in: targets)) g")
                                .font(.title3.bold())
                                .monospacedDigit()
                                .foregroundStyle(isCustom(kind) ? Theme.Palette.amber : Theme.Palette.textPrimary)
                            Text(kind.title)
                                .font(.subheadline)
                                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 70)
                        .background(Theme.Palette.background, in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(isCustom(kind) ? Theme.Palette.amber : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(label(for: kind))
                    .accessibilityHint("Opens an editor to change it")
                }
            }
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    @ViewBuilder
    private func tag(for kind: TargetKind) -> some View {
        let own = isCustom(kind)
        Text(own ? "Your own" : "Suggested")
            .font(.caption.bold())
            .foregroundStyle(own ? Theme.Palette.onAccent : Theme.Palette.textPrimary.opacity(0.75))
            .padding(.horizontal, Theme.Spacing.xs)
            .frame(minHeight: 26)
            .background(own ? Theme.Palette.amber : Theme.Palette.background, in: Capsule())
    }

    private func label(for kind: TargetKind) -> String {
        "\(kind.title), \(kind.value(in: targets)) \(kind.spokenUnit), \(isCustom(kind) ? "your own" : "suggested")"
    }
}

/// Changing one daily number: a big number, − and + to move it in round
/// steps, and a way back to the suggestion.
struct TargetEditorSheet: View {
    let kind: TargetKind
    let suggested: Int?
    let onChange: (Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: Int

    init(kind: TargetKind, value: Int, suggested: Int?, onChange: @escaping (Int?) -> Void) {
        self.kind = kind
        self.suggested = suggested
        self.onChange = onChange
        _value = State(initialValue: value)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.s) {
                ItemBubble(emoji: kind.emoji, size: 60)
                Text(kind.title)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(Theme.Palette.textPrimary)

            HStack(spacing: Theme.Spacing.m) {
                stepButton("minus", direction: -1, disabled: value <= kind.range.lowerBound)
                VStack(spacing: 0) {
                    Text(value.formatted())
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(value)))
                    Text(kind == .kcal ? "kcal a day" : "grams a day")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
                .frame(minWidth: 150)
                .foregroundStyle(Theme.Palette.textPrimary)
                .accessibilityElement(children: .combine)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: set(TargetStepper.step(value, by: 1, kind: kind))
                    case .decrement: set(TargetStepper.step(value, by: -1, kind: kind))
                    @unknown default: break
                    }
                }
                stepButton("plus", direction: 1, disabled: value >= kind.range.upperBound)
            }

            if let suggested, suggested != value {
                Button("Back to suggested · \(kind.text(suggested))") { set(suggested) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    .frame(minHeight: 44)
            } else {
                Text("This is what I'd suggest for your goal.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    .frame(minHeight: 44)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.background.ignoresSafeArea())
        .tint(Theme.Palette.amber)
        .sensoryFeedback(.selection, trigger: value)
    }

    private func set(_ new: Int) {
        withAnimation(.snappy) { value = new }
        onChange(TargetStepper.custom(new, suggested: suggested))
    }

    private func stepButton(_ symbol: String, direction: Int, disabled: Bool) -> some View {
        Button {
            set(TargetStepper.step(value, by: direction, kind: kind))
        } label: {
            Image(systemName: symbol)
                .font(.title2.bold())
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(width: 60, height: 60)
                .background(Theme.Palette.softAmber, in: Circle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(direction > 0 ? "More" : "Less")
    }
}
