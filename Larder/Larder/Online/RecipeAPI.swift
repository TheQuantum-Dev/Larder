//
//  RecipeAPI.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation

/// What to ask the recipe service for. Only ingredient names and the person's
/// goal and diet go out: never photos, and nothing that says who they are.
nonisolated struct OnlineRequest: Hashable, Sendable {
    /// Ingredient names from the pantry to build recipes around, like "chicken".
    var anchors: [String]
    var goal: FitnessGoal?
    var diets: Set<Diet>
    var slot: MealSlot
    var number = 10
    /// The longest a recipe may take, in minutes. Something to cook now, not overnight.
    var maxMinutes = 90
}

nonisolated struct OnlineSearchOutcome: Sendable {
    let recipes: [OnlineRecipeDTO]
    /// The points the service says the search used, when it says.
    let pointsCharged: Double?
    /// How many of the day's points the service says are used in all, when it says.
    /// It's the service's own count, so it corrects ours after a reinstall or
    /// when the same key is used somewhere else too.
    var quotaUsed: Double? = nil
}

nonisolated enum OnlineError: Error, Equatable, Sendable {
    /// No key to use.
    case notConfigured
    /// The key was refused.
    case unauthorized
    /// The day's free points are gone.
    case quotaExceeded
    /// Too many requests too fast.
    case rateLimited
    case offline
    case badResponse
}

/// The recipe service, behind a protocol so tests and debug builds can stand in for it.
nonisolated protocol RecipeAPI: Sendable {
    func search(_ request: OnlineRequest) async throws -> OnlineSearchOutcome
    func recipe(id: Int) async throws -> OnlineRecipeDTO
}
