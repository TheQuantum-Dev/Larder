//
//  InsightsView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftData
import SwiftUI

/// Looking back: the streak, the meals, the money saved. That part is free
/// for everyone, so this tab is never just a locked wall. Budget tracking
/// sits underneath as the Larder Plus part.
struct InsightsView: View {
    @Environment(PurchaseStore.self) private var store
    @Environment(AppModel.self) private var app
    @Query private var meals: [CookedMeal]
    @Query private var pantry: [PantryItem]
    @AppStorage(AppSettings.weeklyBudgetKey) private var weeklyBudget = 0

    @State private var selected: RecipeMatch?
    @State private var showPaywall = false

    private var insights: BudgetInsights {
        BudgetInsights.compute(from: meals, budget: weeklyBudget)
    }

    private var matches: [RecipeMatch] {
        RecipeMatcher.bestMatches(pantry: Set(pantry.map(\.ingredientID)), diets: app.profile.dietSet,
                                  priorities: app.profile.prioritySet, cooking: app.profile.cookingSet).matches
    }

    var body: some View {
        let insights = insights
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    header(insights)
                    streakCard
                    statGrid(insights)
                    mostMadeSection
                    budgetSection(insights)
                }
                .padding(Theme.Spacing.s)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Insights")
        }
        .recipeCookingFlow(selected: $selected, diets: app.profile.dietSet)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView { _ in showPaywall = false }
        }
    }

    // MARK: - For everyone

    private func header(_ insights: BudgetInsights) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            NutmegView()
                .frame(width: 80)
            Text(nutmegLine(insights))
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func nutmegLine(_ insights: BudgetInsights) -> String {
        if insights.mealCount == 0 {
            return "Cook your first meal and I'll start adding it all up here."
        }
        switch insights.standing {
        case .noBudget, .under: return "Here's how your cooking adds up."
        case .over: return "A big week of cooking! No stress."
        }
    }

    private var streakCard: some View {
        let dates = meals.map(\.cookedAt)
        let status = CookingStreak.status(from: dates)
        let best = CookingStreak.best(from: dates)
        return HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundStyle(status == .none ? Theme.Palette.textPrimary.opacity(0.3) : Theme.Palette.amber)
                .frame(width: 60)
            VStack(alignment: .leading, spacing: 0) {
                Text(status.days == 1 ? "1-day streak" : "\(status.days)-day streak")
                    .font(.title2.bold())
                Text(streakLine(status, best: best))
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .accessibilityElement(children: .combine)
    }

    private func streakLine(_ status: CookingStreak.Status, best: Int) -> String {
        // Only worth saying when it's a different number from the one above.
        let bestText = best > status.days ? "Best so far: \(best) \(best == 1 ? "day" : "days")." : ""
        switch status {
        case .none: return "Cook anything today to start one. \(bestText)"
        case .safe: return "You've cooked today. \(bestText)"
        case .atRisk: return "Cook anything today to keep it going. \(bestText)"
        }
    }

    private func statGrid(_ insights: BudgetInsights) -> some View {
        let columns = [GridItem(.flexible(), spacing: Theme.Spacing.xs), GridItem(.flexible(), spacing: Theme.Spacing.xs)]
        return LazyVGrid(columns: columns, spacing: Theme.Spacing.xs) {
            StatTile(title: "Meals made", value: "\(insights.mealCount)")
            StatTile(title: "Saved so far", value: Money.text(insights.totalSaved))
            StatTile(title: "Cooked this week", value: "\(insights.weekMeals)")
            StatTile(title: "Saved this week", value: Money.text(insights.weekSaved))
        }
    }

    /// The recipes made most often, most recent first on a tie.
    @ViewBuilder
    private var mostMadeSection: some View {
        let counts = Dictionary(grouping: meals, by: \.recipeID)
            .map { (meal: $0.value.max { $0.cookedAt < $1.cookedAt }!, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.meal.cookedAt > $1.meal.cookedAt }
            .prefix(3)
        if !counts.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Your go-tos")
                    .font(.headline)
                ForEach(Array(counts), id: \.meal.recipeID) { entry in
                    HStack(spacing: Theme.Spacing.s) {
                        Text(entry.meal.emoji)
                            .font(.title2)
                        Text(entry.meal.title)
                        Spacer()
                        Text(entry.count == 1 ? "once" : "\(entry.count) times")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    }
                    .padding(.horizontal, Theme.Spacing.s)
                    .frame(minHeight: 50)
                    .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                }
            }
            .foregroundStyle(Theme.Palette.textPrimary)
        }
    }

    // MARK: - Budget (Larder Plus)

    @ViewBuilder
    private func budgetSection(_ insights: BudgetInsights) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("Budget")
                    .font(.title3.bold())
                Spacer()
                if !store.isPlusActive {
                    Label("Plus", systemImage: "lock.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
            }
            .foregroundStyle(Theme.Palette.textPrimary)

            if store.isPlusActive {
                weekCard(insights)
                weeksChart(insights)
                cheapestSection
            } else {
                locked
            }
        }
    }

    private func weekCard(_ insights: BudgetInsights) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
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
                let badges = RecipeBadges.reasons(for: match, priorities: app.profile.prioritySet, cooking: app.profile.cookingSet)
                RecipeCard(match: match, badges: badges) { selected = match }
            }
        }
    }

    // MARK: - Without Plus

    private var locked: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                lockedPoint("chart.bar.fill", "This week's cost against your budget")
                lockedPoint("calendar", "Your last four weeks, side by side")
                lockedPoint("fork.knife", "The cheapest things you can make right now")
            }
            Button("See Larder Plus") { showPaywall = true }
                .buttonStyle(PillButtonStyle(fill: Theme.Palette.softAmber))
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
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
