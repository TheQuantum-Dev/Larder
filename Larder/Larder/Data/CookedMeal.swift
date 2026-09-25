//
//  CookedMeal.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation
import SwiftData

/// A meal the person marked as made. This is a light log for "meals this
/// week" and "saved so far", not a receipt or spending ledger.
@Model
final class CookedMeal {
    var recipeID: String
    var title: String
    var emoji: String
    var cookedAt: Date
    var servings: Int
    /// Rough cost of the ingredients, in dollars.
    var cost: Double
    /// Rough amount saved compared with ordering out, in dollars.
    var saved: Double
    /// What was eaten, from the recipe's calories and macros when it was
    /// cooked. Optional because meals logged before this existed have none.
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    /// How many of the recipe's servings were eaten.
    var servingsEaten: Int?

    init(recipeID: String, title: String, emoji: String, cookedAt: Date = Date(),
         servings: Int, cost: Double, saved: Double,
         nutrition: Macros? = nil, servingsEaten: Int? = nil) {
        self.recipeID = recipeID
        self.title = title
        self.emoji = emoji
        self.cookedAt = cookedAt
        self.servings = servings
        self.cost = cost
        self.saved = saved
        self.calories = nutrition?.kcal
        self.protein = nutrition?.protein
        self.carbs = nutrition?.carbs
        self.fat = nutrition?.fat
        self.servingsEaten = servingsEaten
    }

    /// The nutrition that was logged, if there is any.
    var nutrition: Macros? {
        guard let calories else { return nil }
        return Macros(kcal: calories, protein: protein ?? 0, carbs: carbs ?? 0, fat: fat ?? 0)
    }
}
