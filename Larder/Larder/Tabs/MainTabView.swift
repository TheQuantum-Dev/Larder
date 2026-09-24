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
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var meals: [CookedMeal]
    @Query private var pantry: [PantryItem]
    @AppStorage(AppSettings.streakRemindersKey) private var streakReminders = true
    @AppStorage(AppSettings.pantryRemindersKey) private var pantryReminders = true
    @AppStorage(AppSettings.budgetRemindersKey) private var budgetReminders = true
    @AppStorage(AppSettings.weeklyBudgetKey) private var weeklyBudget = 0

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
        .tapFeedback(app.tab)
        .sheet(isPresented: $app.showScan) {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()
                TryItView { items in
                    PantryRepository.add(items, in: context)
                    app.showScan = false
                }
            }
            .presentationDragIndicator(.visible)
        }
        // Any change to the meal log, the pantry, a setting, or coming back to
        // the app re-plans every reminder.
        .task(id: reminderKey) { await refreshReminders() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshReminders() }
        }
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
