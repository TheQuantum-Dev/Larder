//
//  PantryItem.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation
import SwiftData

/// Something the person has in their kitchen. An amount is optional: most
/// things are fine as just "there", and the amount is only for people who
/// want it ("6 eggs"). Nothing in recipe matching depends on it.
@Model
final class PantryItem {
    @Attribute(.unique) var ingredientID: String
    var name: String
    var emoji: String
    var isCustom: Bool
    var addedAt: Date
    /// How much is left, in `unit`. Nil means "we have some".
    var quantity: Double?
    /// A `PantryUnit` raw value. Stored as text so a new unit never breaks old data.
    var unit: String?

    init(ingredientID: String, name: String, emoji: String, isCustom: Bool, addedAt: Date = Date()) {
        self.ingredientID = ingredientID
        self.name = name
        self.emoji = emoji
        self.isCustom = isCustom
        self.addedAt = addedAt
    }

    convenience init(item: ResolvedItem, addedAt: Date = Date()) {
        self.init(ingredientID: item.id, name: item.name, emoji: item.emoji,
                  isCustom: item.isCustom, addedAt: addedAt)
    }

    var resolved: ResolvedItem {
        ResolvedItem(id: ingredientID, name: name, emoji: emoji, isCustom: isCustom)
    }

    /// "6 eggs"-style text for the amount, or nil if none was set.
    var amountText: String? { PantryAmount.text(quantity: quantity, unit: unit) }

    /// Where it's grouped in the Pantry tab. Custom items have no catalog
    /// entry, so they get their own group.
    var category: IngredientCategory? { IngredientCatalog.ingredient(withID: ingredientID)?.category }
}
