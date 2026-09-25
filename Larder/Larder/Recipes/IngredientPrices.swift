//
//  IngredientPrices.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

/// Rough grocery prices, one number per ingredient, in typical U.S. dollars.
/// These are estimates for a "roughly what does this cost" figure, never
/// exact, and they're meant to be shown as "about $2".
nonisolated enum IngredientPrices {
    struct Price: Sendable {
        /// What one unit means, like "1 egg" or "1/2 cup dry".
        let unit: String
        let usd: Double
    }

    /// Salt, pepper, oil and water are assumed to be in the kitchen already.
    static let assumedStaples: Set<String> = ["salt", "black-pepper", "cooking-oil", "water"]

    static let table: [String: Price] = [
        "egg": Price(unit: "1 egg", usd: 0.35),
        "rice": Price(unit: "1/2 cup dry", usd: 0.20),
        "pasta": Price(unit: "100 g dry", usd: 0.30),
        "ramen": Price(unit: "1 pack", usd: 0.60),
        "bread": Price(unit: "1 slice", usd: 0.15),
        "tortilla": Price(unit: "1 tortilla", usd: 0.30),
        "oats": Price(unit: "1/2 cup dry", usd: 0.20),
        "cereal": Price(unit: "1/2 cup", usd: 0.30),
        "onion": Price(unit: "1 medium", usd: 0.60),
        "garlic": Price(unit: "1 clove", usd: 0.10),
        "tomato": Price(unit: "1 medium", usd: 0.60),
        "potato": Price(unit: "1 medium", usd: 0.55),
        "carrot": Price(unit: "1 medium", usd: 0.25),
        "bell-pepper": Price(unit: "1 pepper", usd: 1.10),
        "broccoli": Price(unit: "1 cup florets", usd: 0.60),
        "spinach": Price(unit: "1 handful", usd: 0.45),
        "lettuce": Price(unit: "1 handful", usd: 0.35),
        "cucumber": Price(unit: "1 cucumber", usd: 0.90),
        "celery": Price(unit: "1 stalk", usd: 0.20),
        "avocado": Price(unit: "1 avocado", usd: 1.30),
        "banana": Price(unit: "1 banana", usd: 0.30),
        "apple": Price(unit: "1 apple", usd: 0.90),
        "lemon": Price(unit: "1 lemon", usd: 0.70),
        "frozen-veg": Price(unit: "1 cup", usd: 0.60),
        "cheese": Price(unit: "30 g", usd: 0.55),
        "butter": Price(unit: "1 tbsp", usd: 0.15),
        "milk": Price(unit: "1 cup", usd: 0.30),
        "yogurt": Price(unit: "3/4 cup", usd: 0.75),
        "chicken": Price(unit: "100 g", usd: 0.75),
        "sausage": Price(unit: "1 link", usd: 0.80),
        "tofu": Price(unit: "100 g", usd: 0.55),
        "beans": Price(unit: "1/2 can", usd: 0.60),
        "lentils": Price(unit: "1/4 cup dry", usd: 0.25),
        "canned-tuna": Price(unit: "1 can", usd: 1.30),
        "peanut-butter": Price(unit: "1 tbsp", usd: 0.12),
        "honey": Price(unit: "1 tsp", usd: 0.10),
        "hummus": Price(unit: "1/4 cup", usd: 0.50),
        "tomato-sauce": Price(unit: "1/2 cup", usd: 0.35),
        "salsa": Price(unit: "1/4 cup", usd: 0.30),
        "soy-sauce": Price(unit: "1 tbsp", usd: 0.10),
        "mayo": Price(unit: "1 tbsp", usd: 0.12),
        "pickles": Price(unit: "a few slices", usd: 0.10),
        "olive-oil": Price(unit: "1 tbsp", usd: 0.20),
        "peas": Price(unit: "1/2 cup", usd: 0.30),
        "corn": Price(unit: "1/2 cup", usd: 0.30),
        "broth": Price(unit: "1 cup", usd: 0.35),
        "ginger": Price(unit: "1 thumb", usd: 0.15),
        "mushroom": Price(unit: "1 cup", usd: 0.70),
        "cabbage": Price(unit: "1 cup", usd: 0.20),
        "beef": Price(unit: "100 g", usd: 1.10),
        "turkey": Price(unit: "100 g", usd: 1.00),
        "pork": Price(unit: "100 g", usd: 0.80),
        "bacon": Price(unit: "1 slice", usd: 0.35),
        "fish": Price(unit: "100 g", usd: 1.30),
        "shrimp": Price(unit: "100 g", usd: 1.80),
        "nuts": Price(unit: "1/4 cup", usd: 0.55),
        "sour-cream": Price(unit: "2 tbsp", usd: 0.20),
        "sweet-potato": Price(unit: "1 medium", usd: 0.80),
        "zucchini": Price(unit: "1 medium", usd: 0.80),
        "green-bean": Price(unit: "1 cup", usd: 0.60),
        "bagel": Price(unit: "1 bagel", usd: 0.60),
    ]

    /// Dollars for one recipe line. Staples and unpriced lines count as free.
    static func cost(of line: RecipeIngredient) -> Double {
        guard !assumedStaples.contains(line.id), let price = table[line.id] else { return 0 }
        return price.usd * line.qty
    }
}
