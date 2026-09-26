//
//  RecipeTaste.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation

/// What the person's own choices say about a recipe: hearts and thumbs from
/// their notes, and what they cooked lately. It nudges the order among
/// recipes that are otherwise equally close to ready, and never hides one.
nonisolated struct RecipeTaste: Equatable, Sendable {
    var favorites: Set<String> = []
    var liked: Set<String> = []
    var disliked: Set<String> = []
    /// Cooked in the last couple of days, so something different comes up.
    var recent: Set<String> = []

    static let none = RecipeTaste()

    /// How much a heart or thumbs up lifts a recipe, and how far a thumbs down
    /// sinks it. Lower scores come first, like the rest of the matcher's ordering.
    static let likedBoost = 0.5
    static let dislikedPenalty = 3.0
    static let recentPenalty = 1.0
    /// How many days back "recent" reaches, counting today.
    static let recentDays = 2

    /// Lower is better.
    func adjustment(for id: String) -> Double {
        var score = 0.0
        if disliked.contains(id) {
            score += Self.dislikedPenalty
        } else if liked.contains(id) || favorites.contains(id) {
            score -= Self.likedBoost
        }
        if recent.contains(id) { score += Self.recentPenalty }
        return score
    }

    /// Recipes cooked today or yesterday.
    static func recentIDs(cooked: [(id: String, date: Date)], now: Date = Date(),
                          calendar: Calendar = .current) -> Set<String> {
        let today = calendar.startOfDay(for: now)
        guard let cutoff = calendar.date(byAdding: .day, value: -(recentDays - 1), to: today) else { return [] }
        return Set(cooked.filter { $0.date >= cutoff }.map(\.id))
    }
}

extension RecipeTaste {
    /// From the saved notes. The notes are SwiftData objects, so this is only
    /// for the screens that read them.
    @MainActor
    init(notes: [RecipeNote], recent: Set<String> = []) {
        self.init(favorites: Set(notes.filter(\.isFavorite).map(\.recipeID)),
                  liked: Set(notes.filter { $0.verdict == .up }.map(\.recipeID)),
                  disliked: Set(notes.filter { $0.verdict == .down }.map(\.recipeID)),
                  recent: recent)
    }
}
