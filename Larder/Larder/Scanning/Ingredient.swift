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

/// One item from the bundled ingredient list. Scan results, manual entry and
/// (later) recipes all refer to ingredients by `id`.
nonisolated struct Ingredient: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let emoji: String
    let category: IngredientCategory
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
