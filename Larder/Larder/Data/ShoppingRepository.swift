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

    /// Adds items to the list, with no amounts. Returns how many were new.
    @discardableResult
    static func add(_ items: [ResolvedItem], in context: ModelContext) -> Int {
        add(items.map { ShoppingEntry(item: $0) }, in: context)
    }

    /// Adds things to the list. Something already on it gets the new amount
    /// added to what was there (still to get), rather than a second line.
    /// Returns how many were new.
    @discardableResult
    static func add(_ entries: [ShoppingEntry], in context: ModelContext) -> Int {
        var listed = Dictionary(all(in: context).map { ($0.ingredientID, $0) }, uniquingKeysWith: { first, _ in first })
        let now = Date()
        var added = 0
        for entry in entries {
            if let existing = listed[entry.item.id] {
                let total = AmountMath.sum(existing.isBought ? nil : existing.amount, entry.amount)
                existing.quantity = total?.quantity
                existing.unit = total?.unit.rawValue
                existing.boughtAt = nil
                continue
            }
            let item = ShoppingItem(item: entry.item, addedAt: now)
            item.quantity = entry.amount?.quantity
            item.unit = entry.amount?.unit.rawValue
            context.insert(item)
            listed[entry.item.id] = item
            added += 1
        }
        try? context.save()
        return added
    }

    /// What a recipe is short of, as list entries with amounts where they
    /// can be worked out.
    static func entries(missingFrom match: RecipeMatch) -> [ShoppingEntry] {
        match.missing.compactMap { line in
            IngredientCatalog.resolvedItem(forID: line.id).map { ShoppingEntry(item: $0, amount: ShoppingAmount.amount(for: line)) }
        }
    }

    /// Adds what a recipe is short of, with amounts.
    @discardableResult
    static func addMissing(from match: RecipeMatch, in context: ModelContext) -> Int {
        add(entries(missingFrom: match), in: context)
    }

    static func setAmount(_ amount: Amount?, for item: ShoppingItem, in context: ModelContext) {
        item.quantity = amount?.quantity
        item.unit = amount?.unit.rawValue
        try? context.save()
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

    /// What happened to one thing moved into the pantry, for saying so.
    struct Moved: Equatable {
        let name: String
        /// How much there is now, if known.
        let total: Amount?
        let wasInPantry: Bool
    }

    /// Moves everything ticked off into the pantry, and off the list. New
    /// things arrive with the amount bought; things already there get it
    /// added on, since there's now more of them.
    @discardableResult
    static func moveBoughtToPantry(in context: ModelContext) -> [Moved] {
        let bought = all(in: context).filter(\.isBought)
        guard !bought.isEmpty else { return [] }
        let pantry = Dictionary(PantryRepository.all(in: context).map { ($0.ingredientID, $0) },
                                uniquingKeysWith: { first, _ in first })
        var moved: [Moved] = []
        for item in bought {
            if let saved = pantry[item.ingredientID] {
                // "Some" plus a known amount is that amount; otherwise they add up.
                let total = AmountMath.sum(saved.amount, item.amount)
                saved.quantity = total?.quantity
                saved.unit = total?.unit.rawValue
                moved.append(Moved(name: item.name, total: total, wasInPantry: true))
            } else {
                let added = PantryItem(item: item.resolved)
                added.quantity = item.quantity
                added.unit = item.unit
                context.insert(added)
                moved.append(Moved(name: item.name, total: item.amount, wasInPantry: false))
            }
            context.delete(item)
        }
        try? context.save()
        return moved
    }
}

/// Something to put on the list, and how much of it if that's known.
nonisolated struct ShoppingEntry: Equatable, Sendable {
    let item: ResolvedItem
    var amount: Amount?

    init(item: ResolvedItem, amount: Amount? = nil) {
        self.item = item
        self.amount = amount
    }

    /// What someone typed, like "2 cans of beans" or "milk"; nil if it isn't food.
    static func parse(_ text: String) -> ShoppingEntry? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let line = PantryCommand.parse("add " + trimmed)?.lines.first {
            return ShoppingEntry(item: line.item, amount: line.quantity.map { Amount($0, line.unit ?? .items) })
        }
        return IngredientCatalog.resolve(trimmed).map { ShoppingEntry(item: $0) }
    }
}
