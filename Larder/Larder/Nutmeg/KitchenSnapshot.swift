//
//  KitchenSnapshot.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import Foundation

/// Everything Nutmeg can see, frozen at the moment a message is sent. Both
/// chat engines read only this, never the database, so an answer is always
/// about one consistent picture of the kitchen, and the engines can run off
/// the main thread safely.
nonisolated struct KitchenSnapshot: Sendable {
    struct Item: Sendable, Equatable {
        let id: String
        let name: String
        let emoji: String
        /// "6", "500 g" and so on; nil when no amount was set.
        let amount: String?
    }

    var pantry: [Item] = []
    /// Every recipe that fits the person's diet, best match first.
    var matches: [RecipeMatch] = []
    var mealCount = 0
    var mealsThisWeek = 0
    var totalSaved = 0.0
    var weekSaved = 0.0
    var streak = CookingStreak.Status.none
    var bestStreak = 0
    /// Whole dollars; 0 means no budget set.
    var weeklyBudget = 0
    /// Rough ingredient cost of what was cooked this week.
    var weekCost = 0.0
    var mealGoal = 0
    var priorities: Set<Priority> = []

    var readyMatches: [RecipeMatch] { matches.filter(\.isReady) }
    var pantryIDs: Set<String> { Set(pantry.map(\.id)) }

    func match(for recipeID: String) -> RecipeMatch? {
        matches.first { $0.recipe.id == recipeID }
    }
}

extension KitchenSnapshot {
    /// Builds a snapshot from the live data. Runs on the main actor, where
    /// SwiftData's objects live.
    static func capture(pantry: [PantryItem], meals: [CookedMeal], profile: Profile,
                        weeklyBudget: Int, mealGoal: Int, now: Date = Date()) -> KitchenSnapshot {
        let stats = MealStats.compute(from: meals, now: now)
        let budget = BudgetInsights.compute(from: meals, budget: weeklyBudget, now: now)
        let dates = meals.map(\.cookedAt)
        return KitchenSnapshot(
            pantry: pantry.map { Item(id: $0.ingredientID, name: $0.name, emoji: $0.emoji, amount: $0.amountText) },
            matches: RecipeMatcher.matches(pantry: Set(pantry.map(\.ingredientID)), diets: profile.dietSet,
                                           priorities: profile.prioritySet, cooking: profile.cookingSet,
                                           maxMissing: .max),
            mealCount: stats.mealCount,
            mealsThisWeek: stats.mealsThisWeek,
            totalSaved: stats.totalSaved,
            weekSaved: budget.weekSaved,
            streak: CookingStreak.status(from: dates, now: now),
            bestStreak: CookingStreak.best(from: dates),
            weeklyBudget: weeklyBudget,
            weekCost: budget.weekCost,
            mealGoal: mealGoal,
            priorities: profile.prioritySet)
    }
}

/// One answer from Nutmeg: what to say, plus any recipes to show as cards.
/// Recipe ids are checked against the bundled book, so neither engine can
/// ever put a made-up recipe in front of someone.
nonisolated struct NutmegReply: Equatable, Sendable {
    static let maxRecipes = 3

    let text: String
    let recipeIDs: [String]

    init(_ text: String, recipeIDs: [String] = []) {
        self.text = text
        self.recipeIDs = Self.valid(recipeIDs)
    }

    /// Known ids only, no repeats, at most three.
    static func valid(_ ids: [String]) -> [String] {
        var seen: Set<String> = []
        return ids
            .filter { RecipeStore.recipe(withID: $0) != nil && seen.insert($0).inserted }
            .prefix(maxRecipes)
            .map { $0 }
    }
}
