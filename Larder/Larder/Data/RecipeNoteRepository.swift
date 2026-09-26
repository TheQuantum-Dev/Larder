//
//  RecipeNoteRepository.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation
import SwiftData

/// Reading and changing the hearts and thumbs, in one place like the pantry's
/// and the shopping list's.
enum RecipeNoteRepository {
    /// Most recently touched first.
    static func all(in context: ModelContext) -> [RecipeNote] {
        let sort = [SortDescriptor(\RecipeNote.updatedAt, order: .reverse)]
        return (try? context.fetch(FetchDescriptor<RecipeNote>(sortBy: sort))) ?? []
    }

    static func note(for id: String, in context: ModelContext) -> RecipeNote? {
        var descriptor = FetchDescriptor<RecipeNote>(predicate: #Predicate { $0.recipeID == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Hearts a recipe, or takes the heart back if it's already there.
    static func toggleFavorite(_ ref: RecipeRef, in context: ModelContext, at date: Date = Date()) {
        update(ref, in: context, at: date) { $0.isFavorite.toggle() }
    }

    /// Records a thumbs up or down. Tapping the same one a second time takes it back.
    static func setVerdict(_ verdict: RecipeVerdict, for ref: RecipeRef, in context: ModelContext, at date: Date = Date()) {
        update(ref, in: context, at: date) { $0.verdict = $0.verdict == verdict ? nil : verdict }
    }

    private static func update(_ ref: RecipeRef, in context: ModelContext, at date: Date,
                               _ change: (RecipeNote) -> Void) {
        let note: RecipeNote
        if let existing = self.note(for: ref.id, in: context) {
            note = existing
        } else {
            note = RecipeNote(ref: ref)
            context.insert(note)
        }
        change(note)
        // Keep the name in step, in case the recipe was renamed.
        note.title = ref.title
        note.emoji = ref.emoji
        note.imageURL = ref.imageURL ?? note.imageURL
        note.updatedAt = date
        // A note with neither a heart nor a thumb has nothing left to say.
        if !note.isFavorite && note.verdict == nil { context.delete(note) }
        try? context.save()
    }
}
