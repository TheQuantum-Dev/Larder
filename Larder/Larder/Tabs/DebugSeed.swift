//
//  DebugSeed.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

#if DEBUG
import Foundation
import SwiftData

/// `-seedPantry a,b,c` chooses the pantry by ingredient id.
/// `-seedShopping YES` also puts a few things on the shopping list, one already ticked off.
/// `-seedMeals veggie-omelette@0@8:15,tuna-melt@1@19:30` replaces the meal log with those meals
/// (recipe id, days before today, time), for trying the next-meal card and the streak at
/// exact moments; pair it with `-now`.
/// `-seedFavorites a,b` hearts those recipes and `-seedThumbs a:up,b:down` gives them thumbs.
/// `-seedDemo YES` saves a small pantry and a cooked meal, so the app can be
/// seen without going through onboarding. Add `-seedStreak 5` for meals on the
/// five days before today as well, cycling through a few recipes so the
/// nutrition chart has some variety. Debug builds only.
enum DebugSeed {
    private static let pantry = ["egg", "rice", "onion", "cheese", "bread", "butter", "milk", "pasta",
                                 "tomato-sauce", "banana"]
    private static let recipes = ["egg-fried-rice", "tuna-melt", "chicken-rice-skillet", "veggie-omelette",
                                  "stovetop-mac-cheese", "black-bean-rice-bowl"]

    @MainActor
    static func run(in context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "seedDemo") else { return }
        // `-seedPantry chicken,rice,beans` overrides the pantry that gets saved.
        let ids = UserDefaults.standard.string(forKey: "seedPantry")?.split(separator: ",").map(String.init) ?? pantry
        PantryRepository.replace(with: ids.compactMap { IngredientCatalog.ingredient(withID: $0) }.map(ResolvedItem.init),
                                 in: context)
        if UserDefaults.standard.bool(forKey: "seedShopping"), ShoppingRepository.all(in: context).isEmpty {
            let items = ["eggs", "spinach", "soy-sauce", "yogurt"].compactMap { id -> ResolvedItem? in
                IngredientCatalog.ingredient(withID: id == "eggs" ? "egg" : id).map(ResolvedItem.init)
            }
            ShoppingRepository.add(items, in: context)
            if let first = ShoppingRepository.all(in: context).first {
                ShoppingRepository.toggleBought(first, in: context)
            }
        }
        seedNotes(in: context)
        if seedMeals(in: context) { return }
        guard MealLog.count(in: context) == 0 else { return }
        let extraDays = UserDefaults.standard.integer(forKey: "seedStreak")
        for day in 0...max(extraDays, 0) {
            guard let recipe = RecipeStore.recipe(withID: recipes[day % recipes.count]),
                  let date = Calendar.current.date(byAdding: .day, value: -day, to: Date()) else { continue }
            let summary = MealSummary(recipe: recipe, orderOutPrice: AppSettings.defaultOrderOutPrice)
            MealLog.record(summary, at: date, in: context)
        }
    }

    /// Returns true if `-seedMeals` was given and the meal log was replaced.
    @MainActor
    private static func seedMeals(in context: ModelContext) -> Bool {
        guard let text = UserDefaults.standard.string(forKey: "seedMeals") else { return false }
        for meal in MealLog.meals(in: context) { context.delete(meal) }
        try? context.save()
        let calendar = Calendar.current
        for entry in text.split(separator: ",") {
            let parts = entry.split(separator: "@").map(String.init)
            guard parts.count == 3, let recipe = RecipeStore.recipe(withID: parts[0]),
                  let daysBack = Int(parts[1]) else { continue }
            let time = parts[2].split(separator: ":").compactMap { Int($0) }
            guard time.count == 2,
                  let day = calendar.date(byAdding: .day, value: -daysBack, to: AppClock.now),
                  let date = calendar.date(bySettingHour: time[0], minute: time[1], second: 0, of: day) else { continue }
            MealLog.record(MealSummary(recipe: recipe, orderOutPrice: AppSettings.defaultOrderOutPrice), at: date, in: context)
        }
        return true
    }

    @MainActor
    private static func seedNotes(in context: ModelContext) {
        guard RecipeNoteRepository.all(in: context).isEmpty else { return }
        let defaults = UserDefaults.standard
        for id in defaults.string(forKey: "seedFavorites")?.split(separator: ",").map(String.init) ?? [] {
            if let recipe = RecipeStore.recipe(withID: id) {
                RecipeNoteRepository.toggleFavorite(RecipeRef(recipe), in: context)
            }
        }
        for pair in defaults.string(forKey: "seedThumbs")?.split(separator: ",").map(String.init) ?? [] {
            let parts = pair.split(separator: ":").map(String.init)
            guard parts.count == 2, let recipe = RecipeStore.recipe(withID: parts[0]) else { continue }
            RecipeNoteRepository.setVerdict(parts[1] == "down" ? .down : .up, for: RecipeRef(recipe), in: context)
        }
    }
}
#endif
