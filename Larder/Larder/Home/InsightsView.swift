//
//  InsightsView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftData
import SwiftUI

/// Budget and cost insights, the part of Larder Plus that looks back over the
/// meals you've made. Without Plus it shows what's inside and a way in.
struct InsightsView: View {
    @Environment(PurchaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Query private var meals: [CookedMeal]
    @AppStorage(AppSettings.weeklyBudgetKey) private var weeklyBudget = 0

    let matches: [RecipeMatch]
    let diets: Set<Diet>

    @State private var selected: RecipeMatch?
    @State private var showPaywall = false

    private var insights: BudgetInsights {
        BudgetInsights.compute(from: meals, budget: weeklyBudget)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    if store.isPlusActive {
                        unlocked
                    } else {
                        locked
                    }
                }
                .padding(Theme.Spacing.s)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Budget insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(Theme.Palette.amber)
        .recipeCookingFlow(selected: $selected, diets: diets)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView { _ in showPaywall = false }
        }
    }

    // MARK: - With Plus

    @ViewBuilder
    private var unlocked: some View {
        let insights = insights
        weekCard(insights)
        statGrid(insights)
        weeksChart(insights)
        cheapestSection
    }

    private func weekCard(_ insights: BudgetInsights) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.s) {
                NutmegView()
                    .frame(width: 80)
                Text(nutmegLine(insights))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Ingredients cooked this week")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            HStack(alignment: .firstTextBaseline) {
                Text(Money.text(insights.weekCost))
                    .font(.largeTitle.bold())
                if insights.budget > 0 {
                    Text("of \(Money.text(Double(insights.budget)))")
                        .font(.title3)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
            }

            if insights.budget > 0 {
                ProgressBar(progress: insights.budgetProgress)
                if let line = insights.standingText {
                    Text(line)
                        .font(.subheadline.weight(.semibold))
                }
            } else {
                Text("Set a weekly budget and Nutmeg will keep track of it for you.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                Button("Set a weekly budget") {
                    weeklyBudget = Commitment.suggestedBudget
                }
                .buttonStyle(PillButtonStyle())
                Text("Starts at \(Money.text(Double(Commitment.suggestedBudget))). Change it any time in Settings.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
            }
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func nutmegLine(_ insights: BudgetInsights) -> String {
        if insights.mealCount == 0 {
            return "Cook your first meal and I'll start adding it up here."
        }
        switch insights.standing {
        case .noBudget: return "Here's how your cooking adds up."
        case .under: return "You're doing great this week."
        case .over: return "A big week of cooking! No stress."
        }
    }

    private func statGrid(_ insights: BudgetInsights) -> some View {
        let columns = [GridItem(.flexible(), spacing: Theme.Spacing.xs), GridItem(.flexible(), spacing: Theme.Spacing.xs)]
        return LazyVGrid(columns: columns, spacing: Theme.Spacing.xs) {
            StatTile(title: "Saved this week", value: Money.text(insights.weekSaved))
            StatTile(title: "Saved so far", value: Money.text(insights.totalSaved))
            StatTile(title: "Meals made", value: "\(insights.mealCount)")
            StatTile(title: "Average per serving",
                     value: insights.averageCostPerServing.map(Money.text) ?? "None yet")
        }
    }

    private func weeksChart(_ insights: BudgetInsights) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Last 4 weeks")
                .font(.headline)
            WeekBars(weeks: insights.weeks, budget: insights.budget)
            if let best = insights.bestSave {
                Text("Biggest save: \(best.emoji) \(best.title), about \(Money.text(best.saved)).")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
        }
        .foregroundStyle(Theme.Palette.textPrimary)
    }

    @ViewBuilder
    private var cheapestSection: some View {
        let picks = BudgetInsights.cheapestReady(from: matches)
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(picks.isEmpty ? "Ideas to stretch a budget" : "Cheapest things you can make now")
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            // With nothing ready yet, the cheapest recipes overall still give
            // Nutmeg something useful to show.
            let shown = picks.isEmpty
                ? Array(matches.sorted { $0.recipe.costPerServing < $1.recipe.costPerServing }.prefix(3))
                : picks
            ForEach(shown) { match in
                RecipeCard(match: match) { selected = match }
            }
        }
    }

    // MARK: - Without Plus

    private var locked: some View {
        VStack(spacing: Theme.Spacing.s) {
            NutmegView()
                .frame(height: 100)
            Text("See how your cooking adds up")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                lockedPoint("chart.bar.fill", "This week's cost against your budget")
                lockedPoint("dollarsign.circle.fill", "What you've saved by cooking, week by week")
                lockedPoint("fork.knife", "The cheapest things you can make right now")
            }
            Text("Budget insights are part of Larder Plus. Scanning and recipes stay free.")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                .multilineTextAlignment(.center)
            Button("See Larder Plus") { showPaywall = true }
                .buttonStyle(PillButtonStyle())
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .frame(maxWidth: .infinity)
    }

    private func lockedPoint(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.Palette.amber)
                .frame(width: 30)
            Text(text)
                .font(.body)
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.title2.bold())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.footnote)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .accessibilityElement(children: .combine)
    }
}

/// Four columns of cost, one per week, with the budget drawn as a dashed line.
private struct WeekBars: View {
    let weeks: [BudgetInsights.Week]
    let budget: Int

    /// Room above the tallest bar for its dollar figure.
    private let labelRoom: CGFloat = 20
    private let barRoom: CGFloat = 100

    private var ceiling: Double {
        max(weeks.map(\.cost).max() ?? 0, Double(budget), 1)
    }

    private func barHeight(_ cost: Double) -> CGFloat {
        max(10, barRoom * cost / ceiling)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
                ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                    VStack(spacing: 0) {
                        Text(Money.text(week.cost))
                            .font(.caption.bold())
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .frame(height: labelRoom)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(index == weeks.count - 1 ? Theme.Palette.amber : Theme.Palette.softAmber)
                            .frame(height: barHeight(week.cost))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Week of \(week.start.formatted(.dateTime.month(.wide).day())), \(Money.text(week.cost))")
                }
            }
            .frame(height: barRoom + labelRoom, alignment: .bottom)
            .overlay(alignment: .bottom) { budgetLine }

            HStack(spacing: Theme.Spacing.xs) {
                ForEach(weeks) { week in
                    Text(week.start.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: weeks)
    }

    /// Drawn at the budget's height, on the same scale as the bars.
    @ViewBuilder
    private var budgetLine: some View {
        if budget > 0 {
            VStack(alignment: .trailing, spacing: 0) {
                Text("budget")
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
                Line()
                    .stroke(Theme.Palette.textPrimary.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .frame(height: 2)
            }
            .padding(.bottom, barRoom * Double(budget) / ceiling)
        }
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
