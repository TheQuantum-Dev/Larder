//
//  ShoppingRepository.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation
import SwiftData

/// Reading and changing the shopping list, in one place like the pantry's.
enum ShoppingRepository {
    static func all(in context: ModelContext) -> [ShoppingItem] {
        let sort = [SortDescriptor(\ShoppingItem.addedAt)]
        return (try? context.fetch(FetchDescriptor<ShoppingItem>(sortBy: sort))) ?? []
    }

    /// Adds items to the list, leaving ones that are already on it alone.
    /// Returns how many were new.
    @discardableResult
    static func add(_ items: [ResolvedItem], in context: ModelContext) -> Int {
        let existing = Set(all(in: context).map(\.ingredientID))
        let now = Date()
        var added = 0
        var seen = existing
        for item in items where seen.insert(item.id).inserted {
            context.insert(ShoppingItem(item: item, addedAt: now))
            added += 1
        }
        try? context.save()
        return added
    }

    /// Adds what a recipe is short of.
    @discardableResult
    static func addMissing(from match: RecipeMatch, in context: ModelContext) -> Int {
        let items = match.missing.compactMap { line in
            IngredientCatalog.ingredient(withID: line.id).map(ResolvedItem.init)
        }
        return add(items, in: context)
    }

    /// Things that ran out, added only if the person keeps that switched on.
    @discardableResult
    static func addRunOut(_ items: [ResolvedItem], enabled: Bool, in context: ModelContext) -> Int {
        guard enabled, !items.isEmpty else { return 0 }
        return add(items, in: context)
    }

    static func toggleBought(_ item: ShoppingItem, in context: ModelContext) {
        item.boughtAt = item.isBought ? nil : Date()
        try? context.save()
    }

    static func remove(_ item: ShoppingItem, in context: ModelContext) {
        context.delete(item)
        try? context.save()
    }

    /// Moves everything ticked off into the pantry, and off the list.
    /// Returns how many were moved.
    @discardableResult
    static func moveBoughtToPantry(in context: ModelContext) -> Int {
        let bought = all(in: context).filter(\.isBought)
        guard !bought.isEmpty else { return 0 }
        PantryRepository.add(bought.map(\.resolved), in: context)
        for item in bought { context.delete(item) }
        try? context.save()
        return bought.count
    }
}
