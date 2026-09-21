//
//  ContentView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftData
import SwiftUI

/// Placeholder home screen until the real flow is built. It shows whether Plus
/// is active and presents the paywall.
struct ContentView: View {
    @Environment(PurchaseStore.self) private var store
    @Query private var pantry: [PantryItem]
    @Query private var meals: [CookedMeal]
    @Environment(\.modelContext) private var context
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showPaywall = Self.launchedWithPaywall

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            NutmegView()
                .frame(height: 200)
            Text(store.isPlusActive ? "Larder Plus is active" : "Nutmeg is ready when you are")
                .font(.title3.bold())
                .foregroundStyle(Theme.Palette.textPrimary)
            summary
            Button("See Larder Plus") { showPaywall = true }
                .buttonStyle(PillButtonStyle())
            // Handy while the app is still being built; this moves to Settings.
            Button("Replay the intro") { hasCompletedOnboarding = false }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                .frame(minHeight: 44)
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView { _ in showPaywall = false }
        }
        .task { seedDemoData() }
    }

    /// `-seedDemo YES` saves a small pantry and one meal so the saved data can be
    /// seen without going through the whole flow (debug builds only).
    private func seedDemoData() {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "seedDemo") else { return }
        let ids = ["egg", "rice", "onion", "cheese", "bread", "butter", "milk"]
        PantryRepository.replace(with: ids.compactMap { IngredientCatalog.ingredient(withID: $0) }.map(ResolvedItem.init),
                                 in: context)
        if MealLog.count(in: context) == 0, let recipe = RecipeStore.recipe(withID: "egg-fried-rice") {
            MealLog.record(MealSummary(recipe: recipe, orderOutPrice: AppSettings.defaultOrderOutPrice), in: context)
        }
        #endif
    }

    /// A first look at the real, saved data until the proper home screen exists.
    private var summary: some View {
        let stats = MealStats.compute(from: meals)
        return VStack(spacing: Theme.Spacing.xs) {
            Text(pantry.isEmpty
                 ? "Your pantry is empty for now. Replay the intro to scan your fridge."
                 : "\(pantry.count) things in your pantry")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                .multilineTextAlignment(.center)
            if stats.mealCount > 0 {
                Text("\(stats.mealCount) \(stats.mealCount == 1 ? "meal" : "meals") made · saved about \(Money.text(stats.totalSaved))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Lets a debug build open straight onto the paywall (`-showPaywall`).
    private static var launchedWithPaywall: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-showPaywall")
        #else
        false
        #endif
    }
}

#Preview {
    ContentView()
        .environment(PurchaseStore())
}
