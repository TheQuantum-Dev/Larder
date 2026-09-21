//
//  Ingredient.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation

nonisolated enum IngredientCategory: String, CaseIterable, Sendable {
    case produce, dairyAndEggs, protein, grains, pantry, drinks, snacks

    var title: String {
        switch self {
        case .produce: "Produce"
        case .dairyAndEggs: "Dairy and eggs"
        case .protein: "Protein"
        case .grains: "Grains and bread"
        case .pantry: "Pantry"
        case .drinks: "Drinks"
        case .snacks: "Snacks"
        }
    }
}

/// Things about an ingredient that a diet might rule out. They're set
/// conservatively: when in doubt an ingredient carries the flag, so a diet
/// filter errs toward leaving a recipe out.
nonisolated struct DietTraits: OptionSet, Hashable, Sendable {
    let rawValue: Int
    static let meat = DietTraits(rawValue: 1 << 0)
    static let fish = DietTraits(rawValue: 1 << 1)
    static let pork = DietTraits(rawValue: 1 << 2)
    static let dairy = DietTraits(rawValue: 1 << 3)
    static let egg = DietTraits(rawValue: 1 << 4)
    static let gluten = DietTraits(rawValue: 1 << 5)
    static let nuts = DietTraits(rawValue: 1 << 6)
    static let honey = DietTraits(rawValue: 1 << 7)
    static let alcohol = DietTraits(rawValue: 1 << 8)
}

/// One item from the bundled ingredient list. Scan results, manual entry and
/// (later) recipes all refer to ingredients by `id`.
nonisolated struct Ingredient: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let emoji: String
    let category: IngredientCategory
    let traits: DietTraits
    /// Other names this ingredient goes by, in lowercase.
    let aliases: [String]
}

/// A detected item: either something from the catalog, or a custom name the
/// catalog doesn't know. Two items are the same when their ids match.
nonisolated struct ResolvedItem: Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let emoji: String
    let isCustom: Bool

    static func == (lhs: ResolvedItem, rhs: ResolvedItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(_ ingredient: Ingredient) {
        id = ingredient.id
        name = ingredient.name
        emoji = ingredient.emoji
        isCustom = false
    }

    init(customName: String) {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        id = "custom:" + IngredientCatalog.key(for: trimmed)
        name = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        emoji = "🍽️"
        isCustom = true
    }
}
