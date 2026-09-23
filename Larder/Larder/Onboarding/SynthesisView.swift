//
//  SynthesisView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// Reflects the quiz answers back before asking for anything. The picks start
/// tossed around the screen, then fly together into "your plan".
struct SynthesisView: View {
    let answers: OnboardingAnswers
    let onContinue: () -> Void

    @Namespace private var namespace
    @State private var assembled = false
    /// Drives the scattered chips popping in, right as the screen appears,
    /// so nothing sits static before the fly-together.
    @State private var appeared = false

    private struct Chip: Identifiable {
        let id: String
        let emoji: String
        let title: String
    }

    private var eats: [Chip] { chips(from: answers.diets.ordered, prefix: "diet") }
    private var cooks: [Chip] { chips(from: answers.cooking.ordered, prefix: "cooking") }
    private var cares: [Chip] { chips(from: answers.priorities.ordered, prefix: "priority") }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.s) {
                    NutmegView()
                        .frame(width: 80)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Here's what I know about your week")
                            .font(.title2.bold())
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("Nice. I can already work with this.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if assembled {
                    planCard
                } else {
                    ScatterLayout(height: 300) {
                        ForEach(Array((eats + cooks + cares).enumerated()), id: \.element.id) { index, chip in
                            chipView(chip)
                                .matchedGeometryEffect(id: chip.id, in: namespace)
                                .opacity(appeared ? 1 : 0)
                                .scaleEffect(appeared ? 1 : 0.4)
                                .animation(.spring(response: 0.45, dampingFraction: 0.7)
                                    .delay(Double(min(index, 6)) * 0.05), value: appeared)
                        }
                    }
                }

                Text(summary)
                    .font(.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(Theme.Spacing.s)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Let's check your fridge", action: onContinue)
                .buttonStyle(PillButtonStyle())
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.top, Theme.Spacing.xs)
                .background(Theme.Palette.background)
        }
        .task {
            // The chips pop in immediately; give them just long enough to
            // land before flying together, so nothing sits static in between.
            appeared = true
            try? await Task.sleep(for: .milliseconds(550))
            withAnimation(.spring(response: 0.9, dampingFraction: 0.72)) {
                assembled = true
            }
        }
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Your plan")
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            group("Eats", chips: eats)
            group("Cooks", chips: cooks)
            group("Cares about", chips: cares)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func group(_ title: String, chips: [Chip]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            FlowLayout {
                ForEach(chips) { chip in
                    chipView(chip)
                        .matchedGeometryEffect(id: chip.id, in: namespace)
                }
            }
        }
    }

    private func chipView(_ chip: Chip) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(chip.emoji)
            Text(chip.title).font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.Palette.amber.opacity(0.3), in: Capsule())
    }

    private func chips<Option: QuizOption>(from options: [Option], prefix: String) -> [Chip] {
        options.map { Chip(id: "\(prefix)-\($0.title)", emoji: $0.emoji, title: $0.title) }
    }

    /// Nutmeg's one-line read of what matters to this person.
    private var summary: String {
        let blurbs = answers.priorities.ordered.map(\.blurb)
        switch blurbs.count {
        case 0: return "I'll find dinners that fit your week."
        case 1: return "I'll hunt for dinners that are \(blurbs[0])."
        default:
            let head = blurbs.dropLast().joined(separator: ", ")
            return "I'll hunt for dinners that are \(head) and \(blurbs.last!)."
        }
    }
}
