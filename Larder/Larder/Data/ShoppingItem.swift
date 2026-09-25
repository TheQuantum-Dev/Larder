//
//  ShoppingItem.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation
import SwiftData

/// Something to get on the next shop. Items appear here when the person adds
/// them, when they run out of something, or from a recipe that's a few things
/// short. Ticking one off means it's in the basket, and one tap then moves
/// everything in the basket into the pantry.
@Model
final class ShoppingItem {
    @Attribute(.unique) var ingredientID: String
    var name: String
    var emoji: String
    var isCustom: Bool
    var addedAt: Date
    /// When it was ticked off; nil while it's still to get.
    var boughtAt: Date?

    init(item: ResolvedItem, addedAt: Date = Date()) {
        ingredientID = item.id
        name = item.name
        emoji = item.emoji
        isCustom = item.isCustom
        self.addedAt = addedAt
    }

    var resolved: ResolvedItem {
        ResolvedItem(id: ingredientID, name: name, emoji: emoji, isCustom: isCustom)
    }

    var isBought: Bool { boughtAt != nil }
}
