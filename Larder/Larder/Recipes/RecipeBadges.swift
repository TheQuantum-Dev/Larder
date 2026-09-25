//
//  RecipeBadges.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

/// Short "picked for you" reasons shown on a recipe card, so the onboarding
/// answers feel like they actually did something. Only shown when a badge is
/// clearly true, never guessed.
nonisolated enum RecipeBadges {
    static func reasons(for match: RecipeMatch, priorities: Set<Priority>, cooking: Set<CookingConfidence>,
                        goal: GoalContext? = nil) -> [String] {
        var badges: [String] = []
        let recipe = match.recipe

        // What they're working toward comes first, so the two-badge cap keeps it.
        if let goal, let badge = GoalFit.badge(for: recipe.nutrition, in: goal) {
            badges.append(badge)
        }

        if priorities.contains(.saveMoney) && recipe.costPerServing <= 1 {
            badges.append("💸 Cheap")
        }
        if priorities.contains(.fast) && recipe.minutes <= 15 {
            badges.append("⚡️ Quick")
        }
        if priorities.contains(.eatHealthier) && recipe.healthy {
            badges.append("🥗 Healthier")
        }
        if priorities.contains(.cutWaste) && match.haveCount >= 4 {
            badges.append("♻️ Uses a lot of your pantry")
        }

        // At most two, so a card never feels like a badge board.
        return Array(badges.prefix(2))
    }
}
