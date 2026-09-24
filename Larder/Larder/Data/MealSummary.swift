//
//  MealSummary.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

/// What a cooked meal cost against what ordering the same thing would have.
nonisolated struct MealSummary: Equatable, Sendable {
    let recipeID: String
    let title: String
    let emoji: String
    let servings: Int
    let costPerServing: Double
    let orderOutPrice: Double

    init(recipe: Recipe, orderOutPrice: Double) {
        recipeID = recipe.id
        title = recipe.title
        emoji = recipe.emoji
        servings = recipe.servings
        costPerServing = recipe.costPerServing
        self.orderOutPrice = orderOutPrice
    }

    var totalCost: Double { costPerServing * Double(servings) }
    var orderOutTotal: Double { orderOutPrice * Double(servings) }

    /// Never negative: if a recipe somehow cost more than ordering out, the
    /// honest answer is "nothing saved", not a minus.
    var saved: Double { max(0, orderOutTotal - totalCost) }
}

nonisolated enum Money {
    /// "$12.70".
    static func text(_ dollars: Double) -> String {
        dollars.formatted(.currency(code: "USD"))
    }

    /// "about $12.70", because every figure here is a rough one.
    static func about(_ dollars: Double) -> String {
        "about " + text(dollars)
    }
}

nonisolated enum AppSettings {
    static let orderOutPriceKey = "orderOutPrice"
    /// How many meals from the pantry the person wants to cook this week (0 = no goal).
    static let weeklyMealGoalKey = "weeklyMealGoal"
    /// The weekly food budget in whole dollars (0 = none set).
    static let weeklyBudgetKey = "weeklyBudget"
    /// Whether the evening "keep your streak going" nudge is on (default on).
    static let streakRemindersKey = "streakReminders"
    /// Whether the "your pantry's running low" nudge is on (default on).
    static let pantryRemindersKey = "pantryReminders"
    /// Whether the weekly budget touch-point is on (default on).
    static let budgetRemindersKey = "budgetReminders"
    /// When the pantry-low nudge was last scheduled, so it doesn't repeat every day.
    static let lastPantryReminderKey = "lastPantryReminder"
    /// A rough price for one takeout or delivery meal. It's an assumption,
    /// shown as one, and will be adjustable in Settings.
    static let defaultOrderOutPrice = 14.0
}
