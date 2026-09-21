//
//  HomeView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftData
import SwiftUI

/// Where the app lives after onboarding: Nutmeg, this week's progress, a few
/// things to cook right now, and the pantry itself.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PantryItem.addedAt) private var pantry: [PantryItem]
    @Query private var meals: [CookedMeal]
    @AppStorage(AppSettings.weeklyMealGoalKey) private var mealGoal = 0

    @State private var profile = ProfileStore.load()
    @State private var selected: RecipeMatch?
    @State private var showScan = Self.launchedWith("openScan")
    @State private var showSettings = Self.launchedWith("openSettings")
    @State private var showAllRecipes = false

    private var pantryIDs: Set<String> { Set(pantry.map(\.ingredientID)) }

    private var results: (matches: [RecipeMatch], stretched: Bool) {
        RecipeMatcher.bestMatches(pantry: pantryIDs, diets: profile.dietSet, priorities: profile.prioritySet)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    nutmegCard
                    progressCard
                    cookSection
                    pantrySection
                }
                .padding(Theme.Spacing.s)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(isPresented: $showAllRecipes) {
                RecipeResultsView(matches: results.matches, stretched: results.stretched,
                                  diets: profile.dietSet, onCooked: { _ in },
                                  onAddMore: { showAllRecipes = false; showScan = true })
            }
        }
        .recipeCookingFlow(selected: $selected, diets: profile.dietSet)
        .sheet(isPresented: $showScan) {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()
                TryItView { items in
                    PantryRepository.add(items, in: context)
                    showScan = false
                }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings, onDismiss: { profile = ProfileStore.load() }) {
            SettingsView()
        }
        .task { seedDemoData() }
    }

    // MARK: - Nutmeg

    private var nutmegCard: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                NutmegView()
                    .frame(width: 100)
                Text(HomeGreeting.text(pantryCount: pantry.count,
                                       readyCount: results.matches.filter(\.isReady).count))
                    .font(.title3.bold())
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(pantry.isEmpty ? "Scan my fridge" : "Scan or add more") { showScan = true }
                .buttonStyle(PillButtonStyle())
        }
    }

    // MARK: - This week

    @ViewBuilder
    private var progressCard: some View {
        let stats = MealStats.compute(from: meals)
        if mealGoal > 0 || stats.mealCount > 0 {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if mealGoal > 0 {
                    HStack {
                        Text("This week")
                            .font(.headline)
                        Spacer()
                        if stats.mealsThisWeek >= mealGoal {
                            Label("Goal reached!", systemImage: "checkmark.circle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.Palette.onAccent)
                                .padding(.horizontal, Theme.Spacing.xs)
                                .frame(minHeight: 30)
                                .background(Theme.Palette.sage, in: Capsule())
                        }
                    }
                    ProgressBar(progress: min(1, Double(stats.mealsThisWeek) / Double(mealGoal)))
                    Text("\(Commitment.mealsThisWeekText(count: stats.mealsThisWeek, goal: mealGoal)) meals from your pantry")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
                if stats.mealCount > 0 {
                    Text("\(stats.mealCount) \(stats.mealCount == 1 ? "meal" : "meals") made · saved about \(Money.text(stats.totalSaved))")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
    }

    // MARK: - Cook something

    private var cookSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(pantry.isEmpty ? "Easy ideas to start with" : "Cook something")
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Button("See all") { showAllRecipes = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
            ForEach(results.matches.prefix(3)) { match in
                RecipeCard(match: match) { selected = match }
            }
        }
    }

    // MARK: - Pantry

    private var pantrySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(pantry.isEmpty ? "Your pantry" : "Your pantry · \(pantry.count)")
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)

            if pantry.isEmpty {
                Text("Nothing here yet. Scan your fridge or add things by hand, and they'll show up here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            } else {
                FlowLayout {
                    ForEach(pantry) { item in
                        PantryChip(item: item) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                PantryRepository.remove(ids: [item.ingredientID], in: context)
                            }
                        }
                    }
                    Button { showScan = true } label: {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .frame(minHeight: 40)
                            .overlay(Capsule().strokeBorder(Theme.Palette.textPrimary.opacity(0.3),
                                                            style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                    }
                }
                Text("Tap something to take it off your list.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
            }
        }
        .sensoryFeedback(.selection, trigger: pantry.count)
    }

    // MARK: - Debug

    /// `-openSettings YES` or `-openScan YES` opens that sheet on launch (debug builds only).
    private static func launchedWith(_ key: String) -> Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: key)
        #else
        false
        #endif
    }

    /// `-seedDemo YES` saves a small pantry, a meal and a profile so home can be
    /// seen without going through onboarding (debug builds only).
    private func seedDemoData() {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "seedDemo") else { return }
        let ids = ["egg", "rice", "onion", "cheese", "bread", "butter", "milk", "pasta", "tomato-sauce", "banana"]
        PantryRepository.replace(with: ids.compactMap { IngredientCatalog.ingredient(withID: $0) }.map(ResolvedItem.init),
                                 in: context)
        if MealLog.count(in: context) == 0, let recipe = RecipeStore.recipe(withID: "egg-fried-rice") {
            MealLog.record(MealSummary(recipe: recipe, orderOutPrice: AppSettings.defaultOrderOutPrice), in: context)
        }
        #endif
    }
}

/// A pantry item you can tap to take off the list.
private struct PantryChip: View {
    let item: PantryItem
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: Theme.Spacing.xs) {
                Text(item.emoji)
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "xmark")
                    .font(.caption2.bold())
                    .opacity(0.45)
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(.horizontal, Theme.Spacing.xs)
            .frame(minHeight: 40)
            .background(Theme.Palette.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(item.name)")
    }
}
