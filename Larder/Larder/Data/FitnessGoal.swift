//
//  FitnessGoal.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation

/// What a person is working toward. It steers which recipes come first and how
/// big a day's calories and macros should be. "Just cook" turns every number off.
nonisolated enum FitnessGoal: String, QuizOption {
    case buildMuscle, loseWeight, gainWeight, stayFit, justCook

    var title: String {
        switch self {
        case .buildMuscle: "Build muscle"
        case .loseWeight: "Lose weight"
        case .gainWeight: "Gain weight"
        case .stayFit: "Stay fit"
        case .justCook: "Just cook"
        }
    }

    var emoji: String {
        switch self {
        case .buildMuscle: "💪"
        case .loseWeight: "🍃"
        case .gainWeight: "🍚"
        case .stayFit: "🏃"
        case .justCook: "🍳"
        }
    }

    var detail: String? {
        switch self {
        case .buildMuscle: "High-protein meals that fuel your training"
        case .loseWeight: "Lighter meals that still keep you full"
        case .gainWeight: "Filling, calorie-rich meals"
        case .stayFit: "Balanced meals to keep you feeling good"
        case .justCook: "Recipes only. No calories or numbers."
        }
    }

    /// False for "just cook": no calorie or macro number is shown anywhere.
    var showsNutrition: Bool { self != .justCook }

    /// A sentence for Nutmeg's summary of what the person picked.
    var promise: String? {
        switch self {
        case .buildMuscle: "I'll lean toward protein-packed meals."
        case .loseWeight: "I'll lean toward lighter meals that still fill you up."
        case .gainWeight: "I'll lean toward hearty, calorie-rich meals."
        case .stayFit: "I'll lean toward balanced meals."
        case .justCook: nil
        }
    }
}
