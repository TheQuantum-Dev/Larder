//
//  HomeView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftData
import SwiftUI

/// Today, at a glance. Deliberately short: Nutmeg and the streak, the next
/// meal to cook (which follows the time of day and moves on once you've
/// cooked), how the week's going, and one way to add food. The pantry,
/// recipes and insights each have their own tab.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(OnlineRecipes.self) private var online
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \PantryItem.addedAt) private var pantry: [PantryItem]
    @Query private var meals: [CookedMeal]
    @Query private var listed: [ShoppingItem]
    @Query private var notes: [RecipeNote]
    @AppStorage(AppSettings.weeklyMealGoalKey) private var mealGoal = 0
    @AppStorage(AppSettings.lastGoalCheerKey) private var lastGoalCheer = ""
    @AppStorage(AppSettings.onlineRecipesKey) private var onlineEnabled = false
    @AppStorage(AppSettings.onlineOnlyKey) private var onlineOnly = false
    @AppStorage(AppSettings.hiddenOnlineKey) private var hiddenOnline = ""

    @State private var selected: RecipeMatch?
    /// The time Home is working from. It moves on at each meal boundary and
    /// whenever the app comes back, so the suggestion is never a meal behind.
    @State private var now = AppClock.now

    /// What Home shows, worked out once per render from the pantry, the meal
    /// log, the person's goal, and their hearts and thumbs.
    private struct Plan {
        let next: NextMeal
        let matches: [RecipeMatch]
        let pick: RecipeMatch?
        let goal: GoalContext?
    }

    private func makePlan() -> Plan {
        let cooked = meals.map { (id: $0.recipeID, date: $0.cookedAt) }
        let next = MealPlan.next(now: now, cookedDates: cooked.map(\.date))
        let taste = RecipeTaste(notes: notes, recent: RecipeTaste.recentIDs(cooked: cooked, now: now))
        // What's left of today's target steers which meal fits, when there's a goal.
        let logged = meals.compactMap { meal in meal.nutrition.map { (date: meal.cookedAt, macros: $0) } }
        let goal = MealPlan.goalContext(base: app.profile.goalContext, targets: app.profile.dailyTargets,
                                        eaten: MealPlan.eaten(logged, onMealDay: next.day), mealsLeft: next.mealsLeft)
        // Larder's own recipes and any found online, ranked together (or only
        // the online ones, if that's what the person picked and there are some).
        let matches = RecipePool.matches(bundled: RecipeStore.all, online: online.recipes,
                                         onlineOnly: onlineEnabled && onlineOnly,
                                         hidden: RecipePool.hiddenIDs(hiddenOnline)) { recipes in
            RecipeMatcher.bestMatches(recipes: recipes, pantry: Set(pantry.map(\.ingredientID)),
                                      diets: app.profile.dietSet, priorities: app.profile.prioritySet,
                                      cooking: app.profile.cookingSet, goal: goal, taste: taste).matches
        }
        let picks = NextMealPicker.candidates(from: matches, next: next,
                                              cookedToday: MealPlan.cookedIDs(cooked, onMealDayOf: now), taste: taste)
        return Plan(next: next, matches: matches, pick: picks.first, goal: goal)
    }

    var body: some View {
        let plan = makePlan()
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    header(plan)
                    if let look = app.unlockedLook { unlockCard(look) }
                    StreakCard(dates: meals.map(\.cookedAt), now: now) { app.tab = .insights }
                    nextMealCard(plan)
                    weekCard
                    Button(pantry.isEmpty ? "Scan my fridge" : "Update pantry") { app.showScan = true }
                        .buttonStyle(PillButtonStyle(fill: pantry.isEmpty ? Theme.Palette.amber : Theme.Palette.softAmber))
                }
                .padding(Theme.Spacing.s)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: plan.pick?.id)
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
        .recipeCookingFlow(selected: $selected, diets: app.profile.dietSet, showsNutrition: app.profile.showsNutrition,
                           offersShoppingList: true)
        .onChange(of: app.unlockedLook) { _, look in
            guard look != nil else { return }
            app.homeCheer += 1
            SoundPlayer.unlock()
        }
        .task(id: "\(goalReached)-\(app.tab == .home)") { celebrateGoalIfNew() }
        .task { await keepTimeCurrent() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = AppClock.now }
        }
    }

    /// Wakes at every meal boundary, so the card changes on time even if Home
    /// stays open through lunchtime.
    private func keepTimeCurrent() async {
        now = AppClock.now
        while !Task.isCancelled {
            let wake = MealPlan.nextBoundary(after: AppClock.now)
            try? await Task.sleep(for: .seconds(max(1, wake.timeIntervalSince(AppClock.now))))
            now = AppClock.now
        }
    }

    // MARK: - Small celebrations

    private var goalReached: Bool {
        mealGoal > 0 && MealStats.compute(from: meals).mealsThisWeek >= mealGoal
    }

    /// Once a week, when the meal goal is met while Home is showing.
    private func celebrateGoalIfNew() {
        guard goalReached, app.tab == .home else { return }
        let parts = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let week = "\(parts.yearForWeekOfYear ?? 0)-\(parts.weekOfYear ?? 0)"
        guard lastGoalCheer != week else { return }
        lastGoalCheer = week
        app.homeCheer += 1
        SoundPlayer.congrats()
    }

    private func unlockCard(_ look: NutmegLook) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            NutmegView(skin: look.skin, cheer: app.homeCheer)
                .frame(width: 80)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("You unlocked \(look.title)!")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Nutmeg has a new look, thanks to all that cooking.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                HStack(spacing: Theme.Spacing.xs) {
                    Button("Try it on") {
                        app.unlockedLook = nil
                        app.showSettings = true
                    }
                    .buttonStyle(PillButtonStyle())
                    Button("Later") { app.unlockedLook = nil }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .frame(minHeight: 44)
                        .padding(.horizontal, Theme.Spacing.xs)
                }
            }
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    // MARK: - Nutmeg and the streak

    private func header(_ plan: Plan) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            NutmegView(cheer: app.homeCheer)
                .frame(width: 100)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(HomeGreeting.text(pantryCount: pantry.count,
                                       readyCount: plan.matches.filter(\.isReady).count))
                    .font(.title3.bold())
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - The next meal

    @ViewBuilder
    private func nextMealCard(_ plan: Plan) -> some View {
        if let pick = plan.pick {
            let recipe = pick.recipe
            let badges = RecipeBadges.reasons(for: pick, priorities: app.profile.prioritySet,
                                              cooking: app.profile.cookingSet, goal: plan.goal)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Label(plan.next.title, systemImage: plan.next.slot.symbol)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                if let note = plan.next.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }

                HStack(spacing: Theme.Spacing.s) {
                    RecipeThumb(emoji: recipe.emoji, imageURL: recipe.imageURL, size: 80, emojiSize: 50)
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

                if recipe.isOnline || !badges.isEmpty { BadgeRow(badges: badges, showsOnline: recipe.isOnline) }

                if let nudge = RecipeListAction.nudge(for: pick, listed: Set(listed.map(\.ingredientID)), context: context) {
                    Button(action: nudge.perform) {
                        Label(nudge.isDone ? "On your shopping list" : nudge.title,
                              systemImage: nudge.isDone ? "checkmark.circle.fill" : "cart.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(.plain)
                    .disabled(nudge.isDone)
                }

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
            .id(pick.id)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }

    private func missingNames(_ match: RecipeMatch) -> String {
        match.missing
            .map { IngredientCatalog.displayName(forID: $0.id).lowercased() }
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
