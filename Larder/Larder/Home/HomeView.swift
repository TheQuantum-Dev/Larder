//
//  HomeView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftData
import SwiftUI

/// Today, at a glance. Deliberately short: Nutmeg and the streak, one thing
/// to cook tonight, how the week's going, and one way to add food. The
/// pantry, recipes and insights each have their own tab.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \PantryItem.addedAt) private var pantry: [PantryItem]
    @Query private var meals: [CookedMeal]
    @AppStorage(AppSettings.weeklyMealGoalKey) private var mealGoal = 0

    @State private var selected: RecipeMatch?

    private var matches: [RecipeMatch] {
        RecipeMatcher.bestMatches(pantry: Set(pantry.map(\.ingredientID)), diets: app.profile.dietSet,
                                  priorities: app.profile.prioritySet, cooking: app.profile.cookingSet,
                                  goal: app.profile.goalContext).matches
    }

    private var streak: CookingStreak.Status {
        CookingStreak.status(from: meals.map(\.cookedAt))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    header
                    tonightCard
                    weekCard
                    Button(pantry.isEmpty ? "Scan my fridge" : "Add groceries") { app.showScan = true }
                        .buttonStyle(PillButtonStyle(fill: pantry.isEmpty ? Theme.Palette.amber : Theme.Palette.softAmber))
                }
                .padding(Theme.Spacing.s)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { app.showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .recipeCookingFlow(selected: $selected, diets: app.profile.dietSet, showsNutrition: app.profile.showsNutrition)
    }

    // MARK: - Nutmeg and the streak

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            NutmegView()
                .frame(width: 100)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(HomeGreeting.text(pantryCount: pantry.count,
                                       readyCount: matches.filter(\.isReady).count))
                    .font(.title3.bold())
                    .foregroundStyle(Theme.Palette.textPrimary)
                StreakChip(status: streak)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Tonight's pick

    @ViewBuilder
    private var tonightCard: some View {
        if let pick = matches.first {
            let recipe = pick.recipe
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Tonight's pick")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))

                HStack(spacing: Theme.Spacing.s) {
                    Text(recipe.emoji)
                        .font(.system(size: 50))
                        .frame(width: 80, height: 80)
                        .background(Theme.Palette.amber.opacity(0.25), in: Circle())
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(recipe.title)
                            .font(.title3.bold())
                        Text("\(recipe.minutes) min · \(recipe.costText)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                        if app.profile.showsNutrition {
                            Text(recipe.nutrition.summaryText)
                                .font(.subheadline)
                                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                        }
                        Text(pick.isReady ? "You have everything" : "Missing " + missingNames(pick))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(pick.isReady ? Theme.Palette.sage : Theme.Palette.textPrimary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(Theme.Palette.textPrimary)

                HStack(spacing: Theme.Spacing.s) {
                    Button("Let's cook") { selected = pick }
                        .buttonStyle(PillButtonStyle())
                    Button("More ideas") { app.tab = .recipes }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .frame(minHeight: 44)
                        .padding(.horizontal, Theme.Spacing.xs)
                }
            }
            .padding(Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
    }

    private func missingNames(_ match: RecipeMatch) -> String {
        match.missing
            .map { IngredientCatalog.ingredient(withID: $0.id)?.name.lowercased() ?? $0.id }
            .joined(separator: ", ")
    }

    // MARK: - This week

    @ViewBuilder
    private var weekCard: some View {
        let stats = MealStats.compute(from: meals)
        if mealGoal > 0 || stats.mealCount > 0 {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text("This week")
                        .font(.headline)
                    Spacer()
                    if mealGoal > 0, stats.mealsThisWeek >= mealGoal {
                        Label("Goal reached!", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.Palette.onAccent)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .frame(minHeight: 30)
                            .background(Theme.Palette.sage, in: Capsule())
                    }
                }
                if mealGoal > 0 {
                    ProgressBar(progress: min(1, Double(stats.mealsThisWeek) / Double(mealGoal)))
                }
                Text(weekLine(stats))
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
    }

    private func weekLine(_ stats: MealStats) -> String {
        let meals = "\(Commitment.mealsThisWeekText(count: stats.mealsThisWeek, goal: mealGoal)) meals"
        guard stats.totalSaved > 0 else { return meals }
        return "\(meals) · saved about \(Money.text(stats.totalSaved)) so far"
    }
}

/// The streak, in a small chip under Nutmeg's line. Warm in every state,
/// including when there isn't one yet.
struct StreakChip: View {
    let status: CookingStreak.Status

    var body: some View {
        Label {
            Text(text)
                .foregroundStyle(Theme.Palette.textPrimary)
        } icon: {
            Image(systemName: "flame.fill")
                .foregroundStyle(status == .none ? Theme.Palette.textPrimary.opacity(0.4) : Theme.Palette.amber)
        }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, Theme.Spacing.xs)
            .frame(minHeight: 30)
            .background(background, in: Capsule())
            .accessibilityElement(children: .combine)
    }

    private var text: String {
        switch status {
        case .none: "Cook today to start a streak"
        case .safe(let days): "\(days)-day streak"
        case .atRisk(let days): "\(days) days · cook today to keep it"
        }
    }

    private var background: Color {
        switch status {
        case .none: Theme.Palette.surface
        case .safe: Theme.Palette.amber.opacity(0.3)
        case .atRisk: Theme.Palette.amber.opacity(0.15)
        }
    }
}
