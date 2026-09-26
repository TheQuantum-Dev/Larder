//
//  NextMealPicker.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation

/// Chooses what to offer for the meal that's up next, from recipes the matcher
/// has already ranked by pantry and goal. It never shows something that was
/// already cooked today or that got a thumbs down, prefers a recipe that
/// really suits the meal, and always has something to offer.
nonisolated enum NextMealPicker {
    /// A recipe that suits the meal is worth choosing over a ready one that
    /// doesn't only while it's at most this many ingredients away.
    static let mostMissingForASuitedMeal = 1

    /// The recipes to offer, best first.
    static func candidates(from matches: [RecipeMatch], next: NextMeal, cookedToday: Set<String>,
                           taste: RecipeTaste) -> [RecipeMatch] {
        let fresh = matches.filter { !cookedToday.contains($0.id) }
        let wanted = fresh.filter { !taste.disliked.contains($0.id) }
        let suited = wanted.filter {
            $0.recipe.suits(next.slot) && $0.missing.count <= mostMissingForASuitedMeal
        }
        // Each step gives up a little to keep the card from going empty.
        for pool in [suited, wanted, fresh, matches] where !pool.isEmpty {
            return pool
        }
        return []
    }
}
