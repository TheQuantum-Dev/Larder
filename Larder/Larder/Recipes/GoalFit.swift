//
//  GoalFit.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation

/// How well a recipe suits what someone is working toward.
nonisolated enum GoalFit {
    /// Lower fits better and zero fits fully. It only orders recipes that are
    /// otherwise equal, so it never hides one.
    static func penalty(for recipe: Macros, in context: GoalContext) -> Double {
        let meal = context.perMeal
        switch context.goal {
        case .buildMuscle:
            return max(0, 30 - recipe.protein) / 10 + max(0, 0.6 * meal.kcal - recipe.kcal) / 200
        case .loseWeight:
            return max(0, recipe.kcal - meal.kcal) / 100 + max(0, 20 - recipe.protein) / 10
        case .gainWeight:
            return max(0, meal.kcal - recipe.kcal) / 100
        case .stayFit:
            return abs(recipe.kcal - meal.kcal) / 200 + max(0, 20 - recipe.protein) / 20
        case .justCook:
            return 0
        }
    }

    /// A short label, only when the recipe clearly suits the goal.
    static func badge(for recipe: Macros, in context: GoalContext) -> String? {
        switch context.goal {
        case .buildMuscle:
            return recipe.protein >= 25 ? "💪 High protein · \(recipe.roundedProtein) g" : nil
        case .loseWeight:
            return recipe.kcal <= 0.9 * context.perMeal.kcal && recipe.protein >= 15
                ? "🍃 Light · \(recipe.roundedKcal) kcal" : nil
        case .gainWeight:
            return recipe.kcal >= max(650, 0.9 * context.perMeal.kcal)
                ? "🍚 Hearty · \(recipe.roundedKcal) kcal" : nil
        case .stayFit:
            return recipe.protein >= 20 && (400...700).contains(recipe.kcal)
                ? "⚖️ Balanced · \(recipe.roundedProtein) g protein" : nil
        case .justCook:
            return nil
        }
    }
}
