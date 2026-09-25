//
//  DebugSeed.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

#if DEBUG
import Foundation
import SwiftData

/// `-seedShopping YES` also puts a few things on the shopping list, one already ticked off.
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
        PantryRepository.replace(with: pantry.compactMap { IngredientCatalog.ingredient(withID: $0) }.map(ResolvedItem.init),
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
        guard MealLog.count(in: context) == 0 else { return }
        let extraDays = UserDefaults.standard.integer(forKey: "seedStreak")
        for day in 0...max(extraDays, 0) {
            guard let recipe = RecipeStore.recipe(withID: recipes[day % recipes.count]),
                  let date = Calendar.current.date(byAdding: .day, value: -day, to: Date()) else { continue }
            let summary = MealSummary(recipe: recipe, orderOutPrice: AppSettings.defaultOrderOutPrice)
            MealLog.record(summary, at: date, in: context)
        }
    }
}
#endif
