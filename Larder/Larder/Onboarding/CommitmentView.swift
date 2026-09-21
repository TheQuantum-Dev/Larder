//
//  CommitmentView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftUI

/// A light goal for the week, asked for after the person has cooked something
/// and felt the win. It's an aim, not a rule, and skipping it is always fine.
struct CommitmentView: View {
    /// Only people who said they want to save money are asked about a budget.
    let offersBudget: Bool
    let onSet: (_ mealGoal: Int, _ budget: Int) -> Void
    let onSkip: () -> Void

    @State private var goal = Commitment.defaultMealGoal
    @State private var budget = Commitment.suggestedBudget

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header
                mealGoalSection
                if offersBudget { budgetSection }
            }
            .padding(Theme.Spacing.s)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.xs) {
                Button("Set my goal") { onSet(goal, budget) }
                    .buttonStyle(PillButtonStyle())
                Button("I'll decide later", action: onSkip)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.top, Theme.Spacing.xs)
            .background(Theme.Palette.background)
        }
        .sensoryFeedback(.selection, trigger: goal)
        .sensoryFeedback(.selection, trigger: budget)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            NutmegView()
                .frame(width: 80)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Let's set a little goal")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Just something to aim for this week. You can change it anytime.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var mealGoalSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Meals from your pantry this week")
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Commitment.mealGoals, id: \.self) { number in
                    goalButton(number)
                }
            }
        }
    }

    private func goalButton(_ number: Int) -> some View {
        let isSelected = goal == number
        return Button { goal = number } label: {
            VStack(spacing: 0) {
                Text("\(number)")
                    .font(.title.bold())
                Text("meals")
                    .font(.caption)
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(isSelected ? Theme.Palette.amber.opacity(0.35) : Theme.Palette.surface,
                        in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(isSelected ? Theme.Palette.amber : .clear, lineWidth: 3)
            }
            .scaleEffect(isSelected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .accessibilityLabel("\(number) meals")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Weekly food budget")
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Roughly what you'd like to spend on food each week.")
                .font(.footnote)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))

            HStack(spacing: Theme.Spacing.s) {
                stepButton("minus", label: "Lower the budget", steps: -1)
                Text(budget, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(budget)))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(maxWidth: .infinity)
                stepButton("plus", label: "Raise the budget", steps: 1)
            }
            .padding(Theme.Spacing.s)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: budget)
        }
    }

    private func stepButton(_ symbol: String, label: String, steps: Int) -> some View {
        Button {
            budget = Commitment.adjustedBudget(budget, steps: steps)
        } label: {
            Image(systemName: symbol)
                .font(.title3.bold())
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(width: 60, height: 60)
                .background(Theme.Palette.amber, in: Circle())
        }
        .accessibilityLabel(label)
    }
}
