//
//  ShoppingAmount.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import Foundation

/// How much of a recipe's ingredient to put on the shopping list, in amounts
/// a shop sells: "2 eggs", "250 g chicken", "1 can". Spoonfuls and pinches
/// aren't worth writing down (you'd buy a whole bottle), so they get none.
nonisolated enum ShoppingAmount {
    /// Price units that are counted one by one ("1 egg", "1 medium").
    private static let countedUnits: Set<String> = ["egg", "medium", "pepper", "cucumber", "avocado", "banana", "apple",
                                                    "lemon", "tortilla", "link", "bagel", "lime", "orange", "roll"]
    /// Ingredients that are poured, so their weight is shown as volume.
    private static let liquids: Set<String> = ["milk", "broth", "juice", "cream", "coconut-milk", "stock"]
    /// Less than this and it's a spoonful from a jar you'd buy whole.
    private static let smallestGrams = 40.0

    /// Words that measure out a spoonful or a handful: no amount to buy.
    private static let measureWords: Set<String> = ["cup", "cups", "tbsp", "tablespoon", "tablespoons", "tsp",
                                                    "teaspoon", "teaspoons", "pinch", "pinches", "clove", "cloves",
                                                    "slice", "slices", "dash", "handful", "handfuls", "sprig", "sprigs",
                                                    "stalk", "stalks", "splash", "drizzle", "bunch", "piece", "pieces",
                                                    "scoop", "scoops"]
    /// Words that describe the thing rather than measure it: "2 large eggs".
    private static let describingWords: Set<String> = ["large", "medium", "small", "whole", "fresh", "big", "ripe",
                                                       "extra", "jumbo"]

    static func amount(for line: RecipeIngredient) -> Amount? {
        guard !line.isOptional else { return nil }
        if let price = IngredientPrices.table[line.id], line.qty > 0 {
            let words = price.unit.split(separator: " ").map(String.init)
            switch words.last {
            case "can": return Amount((line.qty * (price.unit.hasPrefix("1/2") ? 0.5 : 1)).rounded(.up), .cans)
            case "pack": return Amount(line.qty.rounded(.up), .packs)
            case let word? where words.first == "1" && countedUnits.contains(word):
                return Amount(line.qty.rounded(.up))
            case "g" where price.unit == "100 g":
                return AmountMath.toBuy(grams: line.qty * 100, liquid: liquids.contains(line.id))
            default: break
            }
        }
        if let grams = line.grams {
            return grams < smallestGrams ? nil : AmountMath.toBuy(grams: grams, liquid: liquids.contains(line.id))
        }
        return amount(inText: line.amount)
    }

    /// Reads an amount off a line like "2 hoagie rolls, split" or "8 ounces
    /// shrimp", for recipes from online that don't come with weights.
    static func amount(inText text: String) -> Amount? {
        let words = text.lowercased()
            .replacingOccurrences(of: "½", with: " 0.5 ").replacingOccurrences(of: "¼", with: " 0.25 ")
            .split { !$0.isLetter && !$0.isNumber && $0 != "." && $0 != "/" }
            .map(String.init)
        guard let first = words.first, let value = number(first) else { return nil }
        var rest = Array(words.dropFirst())
        // "1 1/2 cups": a whole number and a fraction.
        var quantity = value
        if let next = rest.first, next.contains("/"), let fraction = number(next) {
            quantity += fraction
            rest.removeFirst()
        }
        while let next = rest.first, describingWords.contains(next) { rest.removeFirst() }
        guard let unitWord = rest.first else { return nil }
        if ["oz", "ounce", "ounces"].contains(unitWord) { return AmountMath.toBuy(grams: quantity * 28.35) }
        if ["lb", "lbs", "pound", "pounds"].contains(unitWord) { return AmountMath.toBuy(grams: quantity * 453.6) }
        if measureWords.contains(unitWord) { return nil }
        if let unit = PantryCommand.unitWords[unitWord] { return AmountMath.normalised(Amount(quantity, unit)) }
        // Nothing measures it, so it's a count: "2 hoagie rolls".
        return Amount(quantity.rounded(.up))
    }

    private static func number(_ word: String) -> Double? {
        let parts = word.split(separator: "/")
        if parts.count == 2, let top = Double(parts[0]), let bottom = Double(parts[1]), bottom > 0 { return top / bottom }
        return PantryCommand.number(word)
    }
}
