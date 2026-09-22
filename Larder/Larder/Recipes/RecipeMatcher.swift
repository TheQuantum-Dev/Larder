//
//  RecipeMatcher.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

/// How one recipe fits a pantry.
nonisolated struct RecipeMatch: Identifiable, Sendable {
    let recipe: Recipe
    /// Required ingredients the pantry doesn't cover.
    let missing: [RecipeIngredient]
    /// How many required ingredients the recipe has in total.
    let required: Int

    var id: String { recipe.id }
    var isReady: Bool { missing.isEmpty }
    var haveCount: Int { required - missing.count }
}

/// Ranks recipes against what's in the pantry. "Ready now" comes first, then
/// recipes missing only one or two things. Diets are hard rules; priorities
/// and cooking confidence only nudge the order from there, and cheaper meals
/// win any tie.
nonisolated enum RecipeMatcher {
    static func matches(recipes: [Recipe] = RecipeStore.all,
                        pantry: Set<String>,
                        diets: Set<Diet> = [],
                        priorities: Set<Priority> = [],
                        cooking: Set<CookingConfidence> = [],
                        maxMissing: Int = 3) -> [RecipeMatch] {
        let forbidden = Diet.forbiddenTraits(for: diets)
        var result: [RecipeMatch] = []

        for recipe in recipes where recipe.isCompatible(with: diets) {
            var missing: [RecipeIngredient] = []
            var required = 0

            for line in recipe.ingredients where !line.isOptional && !IngredientPrices.assumedStaples.contains(line.id) {
                required += 1
                // Any allowed stand-in counts, but a swap the person's diet
                // rules out never does.
                let options = ([line.id] + line.alternatives).filter { isAllowed($0, forbidden) }
                let covered = options.contains { pantry.contains($0) || IngredientPrices.assumedStaples.contains($0) }
                if !covered { missing.append(line) }
            }

            if missing.count <= maxMissing {
                result.append(RecipeMatch(recipe: recipe, missing: missing, required: required))
            }
        }

        return result.sorted { a, b in
            if a.isReady != b.isReady { return a.isReady }
            if a.missing.count != b.missing.count { return a.missing.count < b.missing.count }
            let prefA = preference(a, priorities, cooking), prefB = preference(b, priorities, cooking)
            if prefA != prefB { return prefA < prefB }
            // Otherwise the cheaper meal first: this is a student budget app.
            if a.recipe.costPerServing != b.recipe.costPerServing { return a.recipe.costPerServing < b.recipe.costPerServing }
            return a.recipe.title < b.recipe.title
        }
    }

    /// What to show a person: recipes within a few items of their pantry, or,
    /// if there are none, the easiest ones to get to, so there is always
    /// something to look at. `stretched` says which happened.
    static func bestMatches(recipes: [Recipe] = RecipeStore.all,
                            pantry: Set<String>,
                            diets: Set<Diet> = [],
                            priorities: Set<Priority> = [],
                            cooking: Set<CookingConfidence> = []) -> (matches: [RecipeMatch], stretched: Bool) {
        let close = matches(recipes: recipes, pantry: pantry, diets: diets, priorities: priorities, cooking: cooking, maxMissing: 3)
        if !close.isEmpty { return (close, false) }
        let wider = matches(recipes: recipes, pantry: pantry, diets: diets, priorities: priorities, cooking: cooking, maxMissing: 6)
        return (wider, !wider.isEmpty)
    }

    private static func isAllowed(_ id: String, _ forbidden: DietTraits) -> Bool {
        IngredientCatalog.ingredient(withID: id)?.traits.isDisjoint(with: forbidden) ?? true
    }

    /// Lower is better.
    private static func preference(_ match: RecipeMatch, _ priorities: Set<Priority>,
                                   _ cooking: Set<CookingConfidence>) -> Double {
        var score = 0.0
        if priorities.contains(.saveMoney) { score += match.recipe.costPerServing }
        if priorities.contains(.fast) { score += Double(match.recipe.minutes) / 10 }
        if priorities.contains(.cutWaste) { score -= Double(match.haveCount) * 0.25 }
        if priorities.contains(.eatHealthier) && !match.recipe.healthy { score += 1.5 }
        // "Mostly microwave and toaster" rules out the stove, unless they also
        // said they're comfortable improvising.
        if cooking.contains(.microwave) && !cooking.contains(.improvise) && !match.recipe.needsNoStove {
            score += 1.5
        }
        return score
    }
}
