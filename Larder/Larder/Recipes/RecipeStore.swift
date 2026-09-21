//
//  RecipeStore.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

/// The bundled recipes, read once from `recipes.json`.
nonisolated enum RecipeStore {
    static let all: [Recipe] = load()

    static func recipe(withID id: String) -> Recipe? {
        all.first { $0.id == id }
    }

    static func load(from bundle: Bundle = .main) -> [Recipe] {
        guard let url = bundle.url(forResource: "recipes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let recipes = try? JSONDecoder().decode([Recipe].self, from: data) else {
            assertionFailure("recipes.json is missing or could not be read")
            return []
        }
        return recipes
    }
}
