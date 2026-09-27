//
//  OnlineRecipeQuality.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation
import NaturalLanguage

/// Checks a recipe from online before anyone cooks from it. Anyone can post a
/// recipe to the sites the service collects from, and the odd joke gets
/// through (one told people to glue bread to an egg), so a recipe has to be
/// written in English, can't mention things that aren't food, and can't be one
/// the service itself rates as poor.
nonisolated enum OnlineRecipeQuality {
    /// Things that should never be in anything you eat. Matched as whole words.
    static let notFood: Set<String> = ["glue", "superglue", "fevikol", "fevicol", "bleach", "detergent", "cement",
                                       "kerosene", "gasoline", "petrol", "soap", "shampoo", "toothpaste",
                                       "poison", "ammonia", "antifreeze"]
    /// Below this the service's own quality score (0 to 100) says to skip it.
    static let lowestScore = 15.0
    /// Short steps like "Cook it." say too little to tell the language from.
    static let languageSampleLength = 60
    static let englishConfidence = 0.6

    static func isTrustworthy(_ dto: OnlineRecipeDTO, steps: [String], ingredients: [String]) -> Bool {
        if let score = dto.spoonacularScore, score < lowestScore { return false }
        let everything = ([dto.title] + steps + ingredients).joined(separator: " ").lowercased()
        let words = Set(everything.split { !$0.isLetter }.map(String.init))
        guard words.isDisjoint(with: notFood) else { return false }
        return isEnglish(steps.joined(separator: " "))
    }

    /// True for English text, and for text too short to tell.
    static func isEnglish(_ text: String) -> Bool {
        guard text.count >= languageSampleLength else { return true }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return (recognizer.languageHypotheses(withMaximum: 3)[.english] ?? 0) >= englishConfidence
    }
}
