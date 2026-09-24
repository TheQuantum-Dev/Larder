//
//  PantryRepository.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation
import SwiftData

/// Reading and changing the saved pantry. Keeping this in one place means the
/// screens don't each need to know how SwiftData is queried.
enum PantryRepository {
    static func all(in context: ModelContext) -> [PantryItem] {
        let sort = [SortDescriptor(\PantryItem.addedAt)]
        return (try? context.fetch(FetchDescriptor<PantryItem>(sortBy: sort))) ?? []
    }

    /// Makes the saved pantry exactly this list.
    static func replace(with items: [ResolvedItem], in context: ModelContext) {
        for existing in all(in: context) { context.delete(existing) }
        try? context.save()
        let now = Date()
        for item in items { context.insert(PantryItem(item: item, addedAt: now)) }
        try? context.save()
    }

    /// Adds items to the pantry, leaving what's already there alone.
    static func add(_ items: [ResolvedItem], in context: ModelContext) {
        let existing = Set(all(in: context).map(\.ingredientID))
        let now = Date()
        for item in items where !existing.contains(item.id) {
            context.insert(PantryItem(item: item, addedAt: now))
        }
        try? context.save()
    }

    /// Sets or clears how much of something is left. A nil quantity goes back
    /// to plain "we have some".
    static func setAmount(_ quantity: Double?, unit: PantryUnit?, for id: String, in context: ModelContext) {
        guard let item = all(in: context).first(where: { $0.ingredientID == id }) else { return }
        item.quantity = quantity
        item.unit = quantity == nil ? nil : unit?.rawValue
        try? context.save()
    }

    /// Takes finished-off ingredients out of the pantry.
    static func remove(ids: Set<String>, in context: ModelContext) {
        for item in all(in: context) where ids.contains(item.ingredientID) {
            context.delete(item)
        }
        try? context.save()
    }
}

/// Which pantry ingredients a recipe uses, so after cooking we can ask what
/// ran out instead of guessing.
nonisolated enum PantryUse {
    static func usedIngredientIDs(by recipe: Recipe, pantry: Set<String>) -> [String] {
        var used: [String] = []
        for line in recipe.ingredients where !line.isOptional && !IngredientPrices.assumedStaples.contains(line.id) {
            let options = [line.id] + line.alternatives
            if let match = options.first(where: { pantry.contains($0) }), !used.contains(match) {
                used.append(match)
            }
        }
        return used
    }
}
