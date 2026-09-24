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
    @AppStorage(AppSettings.streakRemindersKey) private var streakReminders = true

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
        // Any change to the meal log, the setting, or coming back to the app
        // re-plans tonight's streak reminder.
        .task(id: reminderKey) {
            await StreakReminderScheduler.refresh(mealDates: meals.map(\.cookedAt), enabled: streakReminders)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await StreakReminderScheduler.refresh(mealDates: meals.map(\.cookedAt), enabled: streakReminders) }
        }
    }

    private var reminderKey: String { "\(meals.count)-\(streakReminders)" }
}
