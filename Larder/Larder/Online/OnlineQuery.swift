//
//  OnlineQuery.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation

/// Turns what the person has, wants and can't eat into a recipe search.
nonisolated enum OnlineQuery {
    /// Words that keep a halal diet's pork and alcohol out of the results, since
    /// the service has no halal filter of its own.
    static let halalExclusions = ["pork", "bacon", "ham", "lard", "prosciutto", "pancetta", "wine", "beer", "rum",
                                  "vodka", "whiskey", "bourbon", "brandy"]

    /// Goal filters the service understands. They're per serving.
    static func nutrientFilters(for goal: FitnessGoal?) -> [(name: String, value: Int)] {
        switch goal {
        case .buildMuscle: [("minProtein", 30)]
        case .loseWeight: [("maxCalories", 500), ("minProtein", 15)]
        case .gainWeight: [("minCalories", 700)]
        case .stayFit: [("minProtein", 20), ("maxCalories", 700)]
        case .justCook, nil: []
        }
    }

    /// Filtering on nutrients costs the service an extra point.
    static func usesNutrientFilter(_ request: OnlineRequest) -> Bool {
        !nutrientFilters(for: request.goal).isEmpty
    }

    static func items(for request: OnlineRequest) -> [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "number", value: String(request.number)),
            URLQueryItem(name: "addRecipeInformation", value: "true"),
            URLQueryItem(name: "addRecipeNutrition", value: "true"),
            URLQueryItem(name: "fillIngredients", value: "true"),
            URLQueryItem(name: "instructionsRequired", value: "true"),
            URLQueryItem(name: "type", value: request.slot == .breakfast ? "breakfast" : "main course"),
        ]

        if !request.anchors.isEmpty {
            items.append(URLQueryItem(name: "includeIngredients", value: request.anchors.joined(separator: ",")))
            items.append(URLQueryItem(name: "sort", value: "max-used-ingredients"))
        }

        for filter in nutrientFilters(for: request.goal) {
            items.append(URLQueryItem(name: filter.name, value: String(filter.value)))
        }

        // Vegan covers vegetarian, so only the stricter one is asked for.
        var diets: [String] = []
        if request.diets.contains(.vegan) {
            diets.append("vegan")
        } else if request.diets.contains(.vegetarian) {
            diets.append("vegetarian")
        }
        if request.diets.contains(.glutenFree) { diets.append("gluten free") }
        if !diets.isEmpty { items.append(URLQueryItem(name: "diet", value: diets.joined(separator: ","))) }

        var intolerances: [String] = []
        if request.diets.contains(.glutenFree) { intolerances.append("gluten") }
        if request.diets.contains(.dairyFree) { intolerances.append("dairy") }
        if request.diets.contains(.nutFree) { intolerances += ["peanut", "tree nut"] }
        if !intolerances.isEmpty {
            items.append(URLQueryItem(name: "intolerances", value: intolerances.joined(separator: ",")))
        }

        if request.diets.contains(.halal) {
            items.append(URLQueryItem(name: "excludeIngredients", value: halalExclusions.joined(separator: ",")))
        }
        return items
    }
}

/// Picks the few pantry items to build online recipes around. The service wants
/// recipes that use all of them, so two is plenty: one protein, and one thing
/// to go with it.
nonisolated enum OnlineAnchors {
    /// Things that make poor anchors: seasonings, spreads and snacks that most
    /// recipes don't revolve around.
    private static let skipped: Set<String> = ["peanut-butter", "nuts", "garlic", "herbs", "ginger", "jalapeno",
                                               "milk", "butter", "sour-cream"]

    static func pick(from ids: [String], limit: Int = 2) -> [String] {
        let items = ids.compactMap { IngredientCatalog.ingredient(withID: $0) }
            .filter { !skipped.contains($0.id) && !IngredientPrices.assumedStaples.contains($0.id) }

        func first(in categories: [IngredientCategory], skipping chosen: [Ingredient]) -> Ingredient? {
            items.first { item in categories.contains(item.category) && !chosen.contains(item) }
        }

        var chosen: [Ingredient] = []
        if let protein = first(in: [.protein], skipping: chosen) { chosen.append(protein) }
        // With a protein, something to go with it: a grain if there is one, then
        // produce, then dairy or eggs. Without one, the best two of those.
        for category: IngredientCategory in [.grains, .produce, .dairyAndEggs] {
            guard chosen.count < limit else { break }
            if let next = first(in: [category], skipping: chosen) { chosen.append(next) }
        }
        return chosen.prefix(limit).map { $0.id.replacingOccurrences(of: "-", with: " ") }
    }
}
