//
//  Nutrition.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation

/// Energy and macronutrients. Energy is kilocalories; the rest are grams.
nonisolated struct Macros: Hashable, Sendable {
    var kcal = 0.0
    var protein = 0.0
    var carbs = 0.0
    var fat = 0.0

    static let zero = Macros()

    static func + (a: Macros, b: Macros) -> Macros {
        Macros(kcal: a.kcal + b.kcal, protein: a.protein + b.protein, carbs: a.carbs + b.carbs, fat: a.fat + b.fat)
    }

    static func * (m: Macros, factor: Double) -> Macros {
        Macros(kcal: m.kcal * factor, protein: m.protein * factor, carbs: m.carbs * factor, fat: m.fat * factor)
    }
}

/// One food from USDA FoodData Central, per 100 g.
nonisolated struct NutritionEntry: Decodable, Sendable {
    let fdc: Int
    let food: String
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    func macros(grams: Double) -> Macros {
        Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat) * (grams / 100)
    }
}

/// The bundled nutrition table, read once from `nutrition.json`. It is built
/// from USDA FoodData Central (public domain) by `Tools/nutrition`.
nonisolated enum NutritionTable {
    static let foods: [String: NutritionEntry] = load()

    static func entry(for key: String) -> NutritionEntry? {
        foods[key]
    }

    static func load(from bundle: Bundle = .main) -> [String: NutritionEntry] {
        struct File: Decodable { let foods: [String: NutritionEntry] }
        guard let url = bundle.url(forResource: "nutrition", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            assertionFailure("nutrition.json is missing or could not be read")
            return [:]
        }
        return file.foods
    }
}

nonisolated extension Recipe {
    /// Per serving, from the required lines that have a weight. Optional
    /// extras and swaps aren't counted, the same way cost and diet traits work.
    var nutrition: Macros {
        let total = ingredients
            .filter { !$0.isOptional }
            .reduce(Macros.zero) { sum, line in
                guard let grams = line.grams, let entry = NutritionTable.entry(for: line.nutritionKey) else { return sum }
                return sum + entry.macros(grams: grams)
            }
        return total * (1 / Double(max(servings, 1)))
    }
}

nonisolated extension Macros {
    /// Calories to the nearest 10, because a recipe's number is only ever a
    /// good estimate.
    var roundedKcal: Int { Int((kcal / 10).rounded()) * 10 }
    var roundedProtein: Int { Int(protein.rounded()) }
    var roundedCarbs: Int { Int(carbs.rounded()) }
    var roundedFat: Int { Int(fat.rounded()) }

    /// "430 kcal · 22 g protein"
    var summaryText: String {
        "\(roundedKcal) kcal · \(roundedProtein) g protein"
    }
}
