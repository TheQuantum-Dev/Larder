//
//  RecipeNote.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation
import SwiftData

/// A thumbs up or a thumbs down.
nonisolated enum RecipeVerdict: Int, Sendable {
    case down = -1
    case up = 1
}

/// Just enough about a recipe to remember it by: its id, name, emoji and, for
/// recipes that come from online, a photo link. A note keeps only this, so it
/// never depends on the whole recipe still being around.
nonisolated struct RecipeRef: Hashable, Sendable {
    let id: String
    let title: String
    let emoji: String
    let imageURL: String?

    init(id: String, title: String, emoji: String, imageURL: String? = nil) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.imageURL = imageURL
    }

    init(_ recipe: Recipe) {
        self.init(id: recipe.id, title: recipe.title, emoji: recipe.emoji)
    }

    init(_ summary: MealSummary) {
        self.init(id: summary.recipeID, title: summary.title, emoji: summary.emoji)
    }
}

/// How the person feels about one recipe: a favorite heart and a thumbs up or
/// down. A note with neither is deleted, so this only ever holds opinions.
@Model
final class RecipeNote {
    @Attribute(.unique) var recipeID: String
    var title: String
    var emoji: String
    var imageURL: String?
    var isFavorite: Bool
    /// 1 for a thumbs up, -1 for a thumbs down, nil for neither.
    var verdictRaw: Int?
    var updatedAt: Date

    init(ref: RecipeRef, updatedAt: Date = Date()) {
        recipeID = ref.id
        title = ref.title
        emoji = ref.emoji
        imageURL = ref.imageURL
        isFavorite = false
        verdictRaw = nil
        self.updatedAt = updatedAt
    }

    var verdict: RecipeVerdict? {
        get { verdictRaw.flatMap(RecipeVerdict.init(rawValue:)) }
        set { verdictRaw = newValue?.rawValue }
    }

    var ref: RecipeRef {
        RecipeRef(id: recipeID, title: title, emoji: emoji, imageURL: imageURL)
    }
}
