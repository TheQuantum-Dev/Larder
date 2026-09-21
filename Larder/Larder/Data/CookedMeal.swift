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

    init(recipeID: String, title: String, emoji: String, cookedAt: Date = Date(),
         servings: Int, cost: Double, saved: Double) {
        self.recipeID = recipeID
        self.title = title
        self.emoji = emoji
        self.cookedAt = cookedAt
        self.servings = servings
        self.cost = cost
        self.saved = saved
    }
}
