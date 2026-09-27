//
//  PantryComponents.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import SwiftUI

/// Which part of the pantry is showing: everything, one category, or the
/// things that aren't in any category.
nonisolated enum PantryFilter: Hashable, Sendable {
    case all
    case category(IngredientCategory)
    case other

    func includes(_ category: IngredientCategory?) -> Bool {
        switch self {
        case .all: true
        case .category(let wanted): category == wanted
        case .other: category == nil
        }
    }

    var emoji: String {
        switch self {
        case .all: "🧺"
        case .category(let category): Self.emoji(for: category)
        case .other: "🫙"
        }
    }

    var title: String {
        switch self {
        case .all: "All"
        case .category(let category): category.title
        case .other: "Other"
        }
    }

    static func emoji(for category: IngredientCategory?) -> String {
        switch category {
        case .produce: "🥬"
        case .dairyAndEggs: "🥚"
        case .protein: "🍗"
        case .grains: "🍞"
        case .pantry: "🥫"
        case .drinks: "🧃"
        case .snacks: "🍪"
        case nil: "🫙"
        }
    }

    /// The filters worth offering: All, then each category that has something in it.
    static func available(for categories: [IngredientCategory?]) -> [(filter: PantryFilter, count: Int)] {
        var result: [(PantryFilter, Int)] = [(.all, categories.count)]
        for category in IngredientCategory.allCases {
            let count = categories.filter { $0 == category }.count
            if count > 0 { result.append((.category(category), count)) }
        }
        let other = categories.filter { $0 == nil }.count
        if other > 0 { result.append((.other, other)) }
        return result
    }
}

/// Pantry or shopping list, as a pill with a sliding highlight.
struct PantryModeSwitcher: View {
    @Binding var showsShopping: Bool
    let toGetCount: Int
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 4) {
            segment("Pantry", isOn: !showsShopping) { showsShopping = false }
            segment(toGetCount > 0 ? "Shopping · \(toGetCount)" : "Shopping", isOn: showsShopping) { showsShopping = true }
        }
        .padding(4)
        .background(Theme.Palette.surface, in: Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showsShopping)
    }

    private func segment(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isOn ? Theme.Palette.onAccent : Theme.Palette.textPrimary)
                .padding(.horizontal, Theme.Spacing.s)
                .frame(minHeight: 36)
                .background {
                    if isOn {
                        Capsule().fill(Theme.Palette.amber)
                            .matchedGeometryEffect(id: "highlight", in: highlight)
                    }
                }
                .contentTransition(.numericText())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A row of category chips with counts, to narrow what's showing.
struct CategoryChips: View {
    let options: [(filter: PantryFilter, count: Int)]
    @Binding var selection: PantryFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(options, id: \.filter) { option in
                    let isOn = selection == option.filter
                    Button { selection = option.filter } label: {
                        HStack(spacing: 6) {
                            Text(option.filter.emoji)
                            Text(option.filter.title)
                                .font(.subheadline.weight(.semibold))
                            Text("\(option.count)")
                                .font(.caption.bold())
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .frame(minHeight: 20)
                                .background((isOn ? Theme.Palette.onAccent : Theme.Palette.textPrimary).opacity(0.12),
                                            in: Capsule())
                        }
                        .foregroundStyle(isOn ? Theme.Palette.onAccent : Theme.Palette.textPrimary)
                        .padding(.horizontal, Theme.Spacing.s)
                        .frame(minHeight: 40)
                        .background(isOn ? Theme.Palette.amber : Theme.Palette.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selection)
    }
}

/// How much of something, as a small capsule: "6", "500 g", "1 · low", or a
/// quiet "+ amount" when there's no number yet.
struct AmountBadge: View {
    let amount: Amount?
    var isLow = false

    var body: some View {
        Group {
            if let amount {
                Text(isLow ? "\(amount.text) · low" : amount.text)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(isLow ? Theme.Palette.onAccent : Theme.Palette.textPrimary)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .frame(minHeight: 26)
                    .background(isLow ? Theme.Palette.amber : Theme.Palette.background, in: Capsule())
            } else {
                Text("+ amount")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
                    .padding(.horizontal, Theme.Spacing.xs)
                    .frame(minHeight: 26)
                    .overlay {
                        Capsule().strokeBorder(Theme.Palette.textPrimary.opacity(0.25),
                                               style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
            }
        }
        .contentTransition(.numericText())
    }
}

/// The emoji in a soft tinted circle, the way things show in the pantry.
struct ItemBubble: View {
    let emoji: String
    var size: CGFloat = 56

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(Theme.Palette.amber.opacity(0.18), in: Circle())
            .accessibilityHidden(true)
    }
}

/// Setting how much of one thing there is: a big number with − and +, a row
/// of units, and a way to clear it. Every change is handed straight to
/// `onChange`, so there's no save step to forget.
struct AmountEditorView: View {
    let emoji: String
    let name: String
    let emptyNote: String
    let onChange: (Amount?) -> Void
    var destructiveTitle: String?
    var onDestructive: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var quantity: Double?
    @State private var unit: PantryUnit

    init(emoji: String, name: String, amount: Amount?, emptyNote: String, onChange: @escaping (Amount?) -> Void,
         destructiveTitle: String? = nil, onDestructive: (() -> Void)? = nil) {
        self.emoji = emoji
        self.name = name
        self.emptyNote = emptyNote
        self.onChange = onChange
        self.destructiveTitle = destructiveTitle
        self.onDestructive = onDestructive
        _quantity = State(initialValue: amount?.quantity)
        _unit = State(initialValue: amount?.unit ?? .items)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.s) {
                ItemBubble(emoji: emoji, size: 60)
                Text(name)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(Theme.Palette.textPrimary)

            if let quantity {
                HStack(spacing: Theme.Spacing.m) {
                    stepButton("minus", direction: -1, disabled: quantity <= 0)
                    Text(PantryAmount.text(quantity: quantity, unit: unit.rawValue) ?? "")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: quantity))
                        .frame(minWidth: 140)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    stepButton("plus", direction: 1, disabled: false)
                }
                unitChips
                Button("Clear amount") { set(nil) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            } else {
                Text(emptyNote)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                Button("Set an amount") { set(unit.starting) }
                    .buttonStyle(PillButtonStyle(fill: Theme.Palette.softAmber))
            }

            Spacer(minLength: 0)

            if let destructiveTitle, let onDestructive {
                Button(destructiveTitle, role: .destructive) {
                    onDestructive()
                    dismiss()
                }
                .font(.body.weight(.semibold))
                .frame(minHeight: 44)
            }
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.background.ignoresSafeArea())
        .tint(Theme.Palette.amber)
        .tapFeedback(quantity)
    }

    private var unitChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(PantryUnit.allCases) { option in
                    let isOn = option == unit
                    Button {
                        unit = option
                        set(option.starting)
                    } label: {
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isOn ? Theme.Palette.onAccent : Theme.Palette.textPrimary)
                            .padding(.horizontal, Theme.Spacing.s)
                            .frame(minHeight: 36)
                            .background(isOn ? Theme.Palette.amber : Theme.Palette.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }

    private func stepButton(_ symbol: String, direction: Int, disabled: Bool) -> some View {
        Button {
            set(PantryAmount.stepped(quantity ?? 0, by: direction, unit: unit))
        } label: {
            Image(systemName: symbol)
                .font(.title2.bold())
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(width: 60, height: 60)
                .background(Theme.Palette.softAmber, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(direction > 0 ? "More" : "Less")
    }

    private func set(_ newQuantity: Double?) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { quantity = newQuantity }
        onChange(newQuantity.map { Amount($0, unit) })
    }
}
