//
//  QuizOptions.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation

/// Something a person can pick on a quiz screen. Conforming enums list their
/// cases once and every quiz screen can render them.
nonisolated protocol QuizOption: Hashable, Identifiable, CaseIterable {
    var title: String { get }
    var emoji: String { get }
}

nonisolated extension QuizOption {
    var id: Self { self }
}

nonisolated enum Diet: QuizOption {
    case noRestrictions, vegetarian, vegan, halal, glutenFree, dairyFree, nutFree

    var title: String {
        switch self {
        case .noRestrictions: "No restrictions"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .halal: "Halal"
        case .glutenFree: "Gluten-free"
        case .dairyFree: "Dairy-free"
        case .nutFree: "Nut-free"
        }
    }

    var emoji: String {
        switch self {
        case .noRestrictions: "🍽️"
        case .vegetarian: "🥕"
        case .vegan: "🌱"
        case .halal: "🥙"
        case .glutenFree: "🌾"
        case .dairyFree: "🥛"
        case .nutFree: "🥜"
        }
    }
}

nonisolated enum CookingConfidence: QuizOption {
    case microwave, followRecipe, improvise

    var title: String {
        switch self {
        case .microwave: "Mostly microwave and toaster"
        case .followRecipe: "I can follow a recipe"
        case .improvise: "I like to improvise"
        }
    }

    var emoji: String {
        switch self {
        case .microwave: "📟"
        case .followRecipe: "📖"
        case .improvise: "🧑‍🍳"
        }
    }
}

nonisolated enum Priority: QuizOption {
    case saveMoney, cutWaste, eatHealthier, fast

    var title: String {
        switch self {
        case .saveMoney: "Save money"
        case .cutWaste: "Waste less food"
        case .eatHealthier: "Eat healthier"
        case .fast: "Just make it fast"
        }
    }

    var emoji: String {
        switch self {
        case .saveMoney: "💸"
        case .cutWaste: "♻️"
        case .eatHealthier: "🥗"
        case .fast: "⚡️"
        }
    }

    /// How the priority reads in Nutmeg's summary sentence.
    var blurb: String {
        switch self {
        case .saveMoney: "cheap"
        case .cutWaste: "good at using up what you have"
        case .eatHealthier: "healthy"
        case .fast: "quick"
        }
    }
}
