//
//  RecipePool.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation

/// Which recipes a list is built from: Larder's own and the ones found online,
/// ranked together so an online recipe sits wherever it fits best.
nonisolated enum RecipePool {
    /// An online recipe needing more than this many things is left out: it was
    /// found for this pantry, so one that needs a whole shop isn't much of a find.
    static let onlineMaxMissing = 6

    /// Ranks Larder's recipes and the online ones together with `rank`.
    /// With `onlineOnly`, only the online ones are kept, unless there aren't any
    /// (offline, the day's lookups used up, still loading), and then Larder's
    /// own come back so the list is never empty.
    static func matches(bundled: [Recipe], online: [Recipe], onlineOnly: Bool, hidden: Set<String> = [],
                        rank: ([Recipe]) -> [RecipeMatch]) -> [RecipeMatch] {
        let ranked = rank(bundled + online.filter { !hidden.contains($0.id) }).filter { match in
            !match.recipe.isOnline || match.missing.count <= onlineMaxMissing
        }
        guard onlineOnly else { return ranked }
        let fromOnline = ranked.filter(\.recipe.isOnline)
        return fromOnline.isEmpty ? ranked : fromOnline
    }

    /// The hidden online recipes, from how they're saved.
    static func hiddenIDs(_ saved: String) -> Set<String> {
        Set(saved.split(separator: ",").map(String.init))
    }

    /// The saved list with one more recipe hidden.
    static func hiding(_ id: String, in saved: String) -> String {
        hiddenIDs(saved).union([id]).sorted().joined(separator: ",")
    }
}
