//
//  SettingsView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftData
import SwiftUI

/// The few things worth changing after onboarding: what you eat, your weekly
/// goal and budget, and what "ordering out" costs for the savings figure.
struct SettingsView: View {
    @Environment(PurchaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage(AppSettings.weeklyMealGoalKey) private var mealGoal = 0
    @AppStorage(AppSettings.weeklyBudgetKey) private var weeklyBudget = 0
    @AppStorage(AppSettings.orderOutPriceKey) private var orderOutPrice = AppSettings.defaultOrderOutPrice
    @AppStorage(AppSettings.streakRemindersKey) private var streakReminders = true
    @AppStorage(AppSettings.pantryRemindersKey) private var pantryReminders = true
    @AppStorage(AppSettings.budgetRemindersKey) private var budgetReminders = true

    private enum Destination: Hashable { case goal }

    @State private var diets: MultiSelection<Diet>
    @State private var goalName: String
    @State private var path: [Destination] = SettingsView.launchPath
    @State private var showPaywall = false
    @State private var showResetConfirm = false
    private let profile: Profile

    private static let repoURL = URL(string: "https://github.com/TheQuantum-Dev/Larder")!

    init() {
        let saved = ProfileStore.load()
        profile = saved
        var selection = MultiSelection<Diet>(exclusive: .noRestrictions)
        for diet in saved.dietSet { selection.toggle(diet) }
        _diets = State(initialValue: selection)
        _goalName = State(initialValue: Self.goalName(for: saved))
    }

    /// `-openGoalSettings YES` opens straight onto the goal screen (debug builds only).
    private static var launchPath: [Destination] {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "openGoalSettings") ? [.goal] : []
        #else
        []
        #endif
    }

    private static func goalName(for profile: Profile) -> String {
        profile.fitnessGoal?.title ?? "Not set"
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                foodSection
                bodyGoalSection
                goalSection
                savingsSection
                remindersSection
                plusSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Destination.self) { _ in GoalSettingsView() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(Theme.Palette.amber)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView { _ in showPaywall = false }
        }
        .onChange(of: diets.items) { _, newValue in
            var updated = ProfileStore.load()
            updated.diets = newValue.map(\.rawValue).sorted()
            ProfileStore.save(updated)
        }
        .alert("Reset all app data?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes your pantry, cooked meals and preferences, and restarts onboarding. This can't be undone.")
        }
    }

    // MARK: - Sections

    private var foodSection: some View {
        Section("What you eat") {
            FlowLayout {
                ForEach(Diet.allCases) { diet in
                    ItemChip(item: ResolvedItem(id: diet.rawValue, name: diet.title, emoji: diet.emoji, isCustom: false),
                             isChecked: diets.contains(diet)) {
                        diets.toggle(diet)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
            .listRowBackground(Theme.Palette.surface)
            Text("Recipes that don't fit are hidden. For halal, that means no pork or alcohol; the meat itself still needs to be halal-certified.")
                .font(.footnote)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                .listRowBackground(Theme.Palette.surface)
        }
        .tapFeedback(diets.items)
    }

    private var bodyGoalSection: some View {
        Section {
            NavigationLink(value: Destination.goal) {
                LabeledContent("Your goal", value: goalName)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .listRowBackground(Theme.Palette.surface)
        } footer: {
            Text("Sets which recipes come first and your daily calorie and protein targets.")
        }
        .onAppear { goalName = Self.goalName(for: ProfileStore.load()) }
    }

    private var goalSection: some View {
        Section("This week") {
            Picker("Meals from your pantry", selection: $mealGoal) {
                Text("No goal").tag(0)
                ForEach(Commitment.mealGoals, id: \.self) { Text("\($0)").tag($0) }
            }
            .listRowBackground(Theme.Palette.surface)

            Toggle("Weekly food budget", isOn: Binding(
                get: { weeklyBudget > 0 },
                set: { weeklyBudget = $0 ? Commitment.suggestedBudget : 0 }
            ))
            .listRowBackground(Theme.Palette.surface)

            if weeklyBudget > 0 {
                Stepper(value: $weeklyBudget, in: Commitment.budgetRange, step: Commitment.budgetStep) {
                    Text("\(weeklyBudget, format: .currency(code: "USD").precision(.fractionLength(0))) a week")
                }
                .listRowBackground(Theme.Palette.surface)
            }
        }
    }

    private var savingsSection: some View {
        Section {
            Stepper(value: $orderOutPrice, in: 5...40, step: 1) {
                Text("About \(Money.text(orderOutPrice)) a meal")
            }
            .listRowBackground(Theme.Palette.surface)
        } header: {
            Text("Ordering out costs")
        } footer: {
            Text("Used only to work out how much you save by cooking. It's a rough guess, so set it to what you'd really spend.")
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle("Streak reminders", isOn: $streakReminders)
                .listRowBackground(Theme.Palette.surface)
            Toggle("Pantry running low", isOn: $pantryReminders)
                .listRowBackground(Theme.Palette.surface)
            Toggle("Weekly budget check-in", isOn: $budgetReminders)
                .listRowBackground(Theme.Palette.surface)
        } header: {
            Text("Reminders")
        } footer: {
            Text("At most one a day: an evening nudge if your streak is still open, a morning one if your pantry's down to a few things, and a Sunday check-in if you've set a budget. Needs notifications turned on for Larder.")
        }
    }

    private var plusSection: some View {
        Section("Larder Plus") {
            Button { showPaywall = true } label: {
                HStack {
                    Text(store.isPlusActive ? "Larder Plus is active" : "See Larder Plus")
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.4))
                }
            }
            .listRowBackground(Theme.Palette.surface)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Button("Replay onboarding") {
                hasCompletedOnboarding = false
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            .listRowBackground(Theme.Palette.surface)

            Link(destination: Self.repoURL) {
                HStack {
                    Text("View source on GitHub")
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.bold())
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.4))
                }
            }
            .listRowBackground(Theme.Palette.surface)

            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                .listRowBackground(Theme.Palette.surface)
            Text("Larder is open source under the MIT License. Built by Joshua Samuel.")
                .font(.footnote)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                .listRowBackground(Theme.Palette.surface)
            Text("Nutrition data: USDA FoodData Central, public domain. Food facts for barcodes: Open Food Facts.")
                .font(.footnote)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                .listRowBackground(Theme.Palette.surface)

            #if DEBUG
            Button("Reset all app data", role: .destructive) {
                showResetConfirm = true
            }
            .listRowBackground(Theme.Palette.surface)
            #endif
        }
    }

    #if DEBUG
    /// Debug-only: wipes the pantry, meal log, saved profile and settings,
    /// then drops back into onboarding. Never shipped to a release build.
    private func resetAllData() {
        PantryRepository.remove(ids: Set(PantryRepository.all(in: context).map(\.ingredientID)), in: context)
        for meal in MealLog.meals(in: context) { context.delete(meal) }
        try? context.save()
        ProfileStore.save(Profile())
        mealGoal = 0
        weeklyBudget = 0
        orderOutPrice = AppSettings.defaultOrderOutPrice
        hasCompletedOnboarding = false
    }
    #endif
}
