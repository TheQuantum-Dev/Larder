//
//  MainTabView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import SwiftData
import SwiftUI

/// The app after onboarding: five tabs, each with its own navigation. Things
/// every tab can trigger (the scan sheet, the streak reminder) live here so
/// there's exactly one of each.
struct MainTabView: View {
    @State private var app = AppModel()
    @State private var online = OnlineRecipes()
    /// Which meal the online lookup is for; moves on when the app comes back.
    @State private var clock = AppClock.now
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var meals: [CookedMeal]
    @Query private var pantry: [PantryItem]
    @AppStorage(AppSettings.streakRemindersKey) private var streakReminders = true
    @AppStorage(AppSettings.pantryRemindersKey) private var pantryReminders = true
    @AppStorage(AppSettings.budgetRemindersKey) private var budgetReminders = true
    @AppStorage(AppSettings.weeklyBudgetKey) private var weeklyBudget = 0
    @AppStorage(AppSettings.seenLooksKey) private var seenLooks = ""
    @AppStorage(AppSettings.onlineRecipesKey) private var onlineEnabled = false
    @AppStorage(AppSettings.autoAddToShoppingKey) private var autoAddToShopping = true

    var body: some View {
        TabView(selection: $app.tab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("Pantry", systemImage: "refrigerator.fill", value: AppTab.pantry) {
                PantryView()
            }
            Tab("Recipes", systemImage: "fork.knife", value: AppTab.recipes) {
                RecipesView()
            }
            Tab("Insights", systemImage: "chart.bar.fill", value: AppTab.insights) {
                InsightsView()
            }
            Tab(value: AppTab.nutmeg) {
                NutmegChatView()
            } label: {
                Label {
                    Text("Nutmeg")
                } icon: {
                    Image(.nutmegTab)
                }
            }
        }
        .tint(Theme.Palette.amber)
        .environment(app)
        .environment(online)
        .tapFeedback(app.tab)
        .sheet(isPresented: $app.showSettings, onDismiss: app.reloadProfile) {
            // A sheet is its own tree, so it gets the shared objects it reads passed in.
            SettingsView()
                .environment(online)
        }
        .sheet(isPresented: $app.showScan) {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()
                TryItView(mode: .update) { review in
                    // Anything marked all gone goes on the shopping list, same as after cooking.
                    let removed = PantryRepository.apply(review.update, in: context)
                    ShoppingRepository.addRunOut(removed, enabled: autoAddToShopping, in: context)
                    app.showScan = false
                }
            }
            .presentationDragIndicator(.visible)
        }
        // Any change to the meal log, the pantry, a setting, or coming back to
        // the app re-plans every reminder.
        .task {
            #if DEBUG
            DebugSeed.run(in: context)
            // `-openScan YES` opens "Update pantry" straight away.
            if UserDefaults.standard.bool(forKey: "openScan") { app.showScan = true }
            #endif
        }
        .task(id: meals.count) { announceNewLooks() }
        .task(id: reminderKey) { await refreshReminders() }
        .task(id: onlineKey) { await online.refresh(onlineRequest, enabled: onlineEnabled) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            clock = AppClock.now
            Task { await refreshReminders() }
        }
    }

    // MARK: - Online recipes

    /// What to look up: a couple of pantry items to build around, the goal and
    /// diet, and which meal it is. Only these words go out, never a photo.
    private var onlineRequest: OnlineRequest {
        OnlineRequest(anchors: OnlineAnchors.pick(from: pantry.map(\.ingredientID)),
                      goal: app.profile.fitnessGoal, diets: app.profile.dietSet,
                      slot: MealPlan.slot(at: clock))
    }

    /// The lookup runs again only when its question changes, so tapping around
    /// the pantry doesn't spend the day's free lookups.
    private var onlineKey: OnlineKey { OnlineKey(request: onlineRequest, enabled: onlineEnabled) }

    private struct OnlineKey: Hashable {
        let request: OnlineRequest
        let enabled: Bool
    }

    /// Tells the person once when cooking earns Nutmeg a new look.
    private func announceNewLooks() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "unlockCoral"), app.unlockedLook == nil {
            app.unlockedLook = .coral
            return
        }
        #endif
        let earned = NutmegLook.earned(bestStreak: CookingStreak.best(from: meals.map(\.cookedAt)),
                                       mealCount: meals.count)
        let seen = Set(seenLooks.split(separator: ",").map(String.init))
        guard let fresh = NutmegLook.allCases.first(where: { earned.contains($0) && !seen.contains($0.rawValue) }) else { return }
        seenLooks = (seen.union([fresh.rawValue])).sorted().joined(separator: ",")
        app.unlockedLook = fresh
    }

    private var reminderKey: String {
        "\(meals.count)-\(pantry.count)-\(streakReminders)-\(pantryReminders)-\(budgetReminders)-\(weeklyBudget)"
    }

    private func refreshReminders() async {
        await StreakReminderScheduler.refresh(mealDates: meals.map(\.cookedAt), enabled: streakReminders)
        await PantryLowReminderScheduler.refresh(pantryCount: pantry.count, enabled: pantryReminders)
        await BudgetReminderScheduler.refresh(weeklyBudgetIsSet: weeklyBudget > 0, enabled: budgetReminders)
    }
}
