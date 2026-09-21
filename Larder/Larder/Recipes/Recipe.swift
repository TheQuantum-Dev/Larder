//
//  Recipe.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

nonisolated enum Equipment: String, Codable, CaseIterable, Sendable {
    case pan, pot, microwave, kettle, toaster, oven

    var title: String {
        switch self {
        case .pan: "Frying pan"
        case .pot: "Pot"
        case .microwave: "Microwave"
        case .kettle: "Kettle"
        case .toaster: "Toaster"
        case .oven: "Oven"
        }
    }
}

/// One line of a recipe. `qty` is how many of the ingredient's price unit the
/// line uses (see `IngredientPrices`), which is what turns a recipe into a
/// rough cost.
nonisolated struct RecipeIngredient: Codable, Hashable, Sendable {
    let id: String
    /// How it reads in the recipe, like "2 eggs".
    let amount: String
    let qty: Double
    let optional: Bool?
    /// Other ingredients that can stand in for this one.
    let alt: [String]?

    var isOptional: Bool { optional ?? false }
    var alternatives: [String] { alt ?? [] }
}

nonisolated struct RecipeStep: Codable, Hashable, Sendable {
    let text: String
    /// Seconds to wait, if this step has a timer.
    let timer: Int?
}

nonisolated struct Recipe: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let emoji: String
    let minutes: Int
    let servings: Int
    let equipment: [Equipment]
    let ingredients: [RecipeIngredient]
    let steps: [RecipeStep]
    /// One friendly line from Nutmeg.
    let tip: String

    /// What a diet could object to, worked out from the required ingredients
    /// rather than typed in by hand, so a label can't be wrong.
    var traits: DietTraits {
        ingredients
            .filter { !$0.isOptional }
            .compactMap { IngredientCatalog.ingredient(withID: $0.id)?.traits }
            .reduce([], { $0.union($1) })
    }

    /// True if no stove is needed, so it works in a dorm room.
    var needsNoStove: Bool {
        Set(equipment).isSubset(of: [.microwave, .kettle, .toaster])
    }

    /// Rough cost of the required ingredients, per serving, in dollars.
    var costPerServing: Double {
        let total = ingredients
            .filter { !$0.isOptional }
            .reduce(0.0) { $0 + IngredientPrices.cost(of: $1) }
        return total / Double(max(servings, 1))
    }

    func isCompatible(with diets: Set<Diet>) -> Bool {
        traits.isDisjoint(with: Diet.forbiddenTraits(for: diets))
    }
}

extension Diet {
    /// What each diet rules out. Halal here means no pork and no alcohol; the
    /// meat itself still needs to be halal-certified, which we can't know.
    nonisolated var forbiddenTraits: DietTraits {
        switch self {
        case .noRestrictions: []
        case .vegetarian: [.meat, .fish]
        case .vegan: [.meat, .fish, .dairy, .egg, .honey]
        case .halal: [.pork, .alcohol]
        case .glutenFree: [.gluten]
        case .dairyFree: [.dairy]
        case .nutFree: [.nuts]
        }
    }

    nonisolated static func forbiddenTraits(for diets: Set<Diet>) -> DietTraits {
        diets.reduce([]) { $0.union($1.forbiddenTraits) }
    }
}
