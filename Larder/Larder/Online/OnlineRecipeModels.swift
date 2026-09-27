//
//  OnlineRecipeModels.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation

// What the recipe service sends back. Every field a recipe might not have is
// optional, and one odd recipe in a batch is skipped rather than failing the lot.

nonisolated struct OnlineSearchResponse: Decodable, Sendable {
    let results: [OnlineRecipeDTO]

    private enum CodingKeys: String, CodingKey { case results }

    /// Decodes one recipe at a time so a single bad one doesn't lose the rest.
    private struct Lossy: Decodable {
        let recipe: OnlineRecipeDTO?
        init(from decoder: Decoder) throws {
            recipe = try? OnlineRecipeDTO(from: decoder)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = (try container.decodeIfPresent([Lossy].self, forKey: .results) ?? []).compactMap(\.recipe)
    }
}

nonisolated struct OnlineRecipeDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let image: String?
    let servings: Int?
    let readyInMinutes: Int?
    /// U.S. cents per serving.
    let pricePerServing: Double?
    let sourceName: String?
    let sourceUrl: String?
    let creditsText: String?
    let vegetarian: Bool?
    let vegan: Bool?
    let glutenFree: Bool?
    let dairyFree: Bool?
    let veryHealthy: Bool?
    let dishTypes: [String]?
    let extendedIngredients: [OnlineIngredientDTO]?
    let analyzedInstructions: [OnlineInstructionDTO]?
    let nutrition: OnlineNutritionDTO?
    /// The service's own quality score, 0 to 100.
    var spoonacularScore: Double? = nil
}

nonisolated struct OnlineIngredientDTO: Decodable, Sendable {
    let name: String?
    let nameClean: String?
    let original: String?
    let amount: Double?
    let unit: String?
}

nonisolated struct OnlineInstructionDTO: Decodable, Sendable {
    let steps: [OnlineStepDTO]?
}

nonisolated struct OnlineStepDTO: Decodable, Sendable {
    let step: String
    let equipment: [OnlineNamedDTO]?
    let length: OnlineLengthDTO?
}

nonisolated struct OnlineNamedDTO: Decodable, Sendable {
    let name: String?
}

nonisolated struct OnlineLengthDTO: Decodable, Sendable {
    let number: Double?
    let unit: String?
}

nonisolated struct OnlineNutritionDTO: Decodable, Sendable {
    let nutrients: [OnlineNutrientDTO]?
}

nonisolated struct OnlineNutrientDTO: Decodable, Sendable {
    let name: String
    let amount: Double
    let unit: String?
}
