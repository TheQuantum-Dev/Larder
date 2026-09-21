//
//  PantryItem.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation
import SwiftData

/// Something the person has in their kitchen. A pantry is simply which items
/// are present; amounts aren't tracked, on purpose, to keep this from turning
/// into inventory software.
@Model
final class PantryItem {
    @Attribute(.unique) var ingredientID: String
    var name: String
    var emoji: String
    var isCustom: Bool
    var addedAt: Date

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
}
