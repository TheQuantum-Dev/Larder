//
//  RecipeReactions.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import SwiftData
import SwiftUI

/// A heart that saves a recipe to Favorites. It reads and writes the person's
/// note for that recipe, so every heart in the app agrees with the others.
struct FavoriteButton: View {
    let ref: RecipeRef

    @Environment(\.modelContext) private var context
    @Query private var notes: [RecipeNote]

    init(ref: RecipeRef) {
        self.ref = ref
        let id = ref.id
        _notes = Query(filter: #Predicate<RecipeNote> { $0.recipeID == id })
    }

    private var isFavorite: Bool { notes.first?.isFavorite ?? false }

    var body: some View {
        Button {
            RecipeNoteRepository.toggleFavorite(ref, in: context)
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.subheadline.bold())
                .foregroundStyle(isFavorite ? Theme.Palette.amber : Theme.Palette.textPrimary)
                .symbolEffect(.bounce, value: isFavorite)
                .frame(width: 40, height: 40)
                .background(Theme.Palette.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .tapFeedback(isFavorite)
        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
    }
}

/// Two pills, thumbs up and thumbs down. Tapping the one that's already
/// chosen takes it back. Nothing is ever hidden because of a thumbs down: it
/// only stops the recipe being picked for you.
struct ThumbsBar: View {
    let ref: RecipeRef
    var height: CGFloat = 50
    /// Called after a tap with what the recipe has now (nil once a thumb is taken back).
    var onChange: (RecipeVerdict?) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Query private var notes: [RecipeNote]

    init(ref: RecipeRef, height: CGFloat = 50, onChange: @escaping (RecipeVerdict?) -> Void = { _ in }) {
        self.ref = ref
        self.height = height
        self.onChange = onChange
        let id = ref.id
        _notes = Query(filter: #Predicate<RecipeNote> { $0.recipeID == id })
    }

    private var verdict: RecipeVerdict? { notes.first?.verdict }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            thumb(.up, title: "Like it", symbol: "hand.thumbsup")
            thumb(.down, title: "Not for me", symbol: "hand.thumbsdown")
        }
        .tapFeedback(verdict?.rawValue ?? 0)
    }

    private func thumb(_ choice: RecipeVerdict, title: String, symbol: String) -> some View {
        let selected = verdict == choice
        return Button {
            RecipeNoteRepository.setVerdict(choice, for: ref, in: context)
            onChange(selected ? nil : choice)
        } label: {
            Label(title, systemImage: selected ? symbol + ".fill" : symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .symbolEffect(.bounce, value: selected)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(selected ? Theme.Palette.amber.opacity(0.35) : Theme.Palette.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(selected ? Theme.Palette.amber : .clear, lineWidth: 2) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
