//
//  NutritionTargets.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation

nonisolated enum BiologicalSex: String, CaseIterable, Identifiable, Sendable {
    case female, male

    var id: String { rawValue }
    var title: String { self == .female ? "Female" : "Male" }
}

nonisolated enum ActivityLevel: String, CaseIterable, Identifiable, Sendable {
    case sedentary, light, moderate, veryActive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sedentary: "Mostly sitting"
        case .light: "Lightly active"
        case .moderate: "Moderately active"
        case .veryActive: "Very active"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: "A desk and short walks"
        case .light: "Walking to class, a workout or two a week"
        case .moderate: "Training three to five days a week"
        case .veryActive: "Hard training most days"
        }
    }

    /// How many times the resting rate a typical day burns.
    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .veryActive: 1.725
        }
    }
}

/// What the calorie estimate needs. Anything left out just means a rougher guess.
nonisolated struct BodyStats: Equatable, Sendable {
    var birthYear: Int?
    var sex: BiologicalSex?
    var heightCm: Double?
    var weightKg: Double?
    var activity: ActivityLevel = .light

    func age(now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let birthYear else { return nil }
        let age = calendar.component(.year, from: now) - birthYear
        return (13...100).contains(age) ? age : nil
    }

    /// Numbers that can't be a real person are ignored, so a slip of the
    /// finger can't produce an absurd target.
    var validHeightCm: Double? { heightCm.flatMap { (100...230).contains($0) ? $0 : nil } }
    var validWeightKg: Double? { weightKg.flatMap { (30...250).contains($0) ? $0 : nil } }
}

/// A day's worth of energy and macros to aim for.
nonisolated struct DailyTargets: Equatable, Sendable {
    var kcal: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    /// False when there weren't enough body stats and a 2,000 kcal day stood in.
    var isPersonal: Bool

    var macros: Macros {
        Macros(kcal: Double(kcal), protein: Double(protein), carbs: Double(carbs), fat: Double(fat))
    }

    /// About what one meal should come to: a third of the day.
    var perMeal: Macros { macros * (1.0 / 3.0) }
}

/// A goal together with what one meal should roughly be, which is all recipe
/// ranking needs to know.
nonisolated struct GoalContext: Equatable, Sendable {
    let goal: FitnessGoal
    let perMeal: Macros
}

/// Rough daily targets from the Mifflin-St Jeor equation, nudged by the goal.
/// These are estimates for cooking, not medical advice.
nonisolated enum NutritionTargets {
    static let baselineKcal = 2_000.0

    static func targets(for goal: FitnessGoal, stats: BodyStats, now: Date = Date(),
                        calendar: Calendar = .current) -> DailyTargets? {
        guard goal.showsNutrition else { return nil }

        let age = stats.age(now: now, calendar: calendar)
        // An app never puts anyone under 18 on a calorie deficit.
        let goal = (goal == .loseWeight && (age ?? 18) < 18) ? FitnessGoal.stayFit : goal

        var maintenance = baselineKcal
        var isPersonal = false
        if let age, let height = stats.validHeightCm, let weight = stats.validWeightKg {
            let offset: Double = switch stats.sex {
            case .male?: 5
            case .female?: -161
            case nil: -78
            }
            maintenance = (10 * weight + 6.25 * height - 5 * Double(age) + offset) * stats.activity.factor
            isPersonal = true
        }

        let kcal = max(maintenance + adjustment(for: goal, maintenance: maintenance), minimumKcal(stats.sex))

        let protein: Double
        if let weight = stats.validWeightKg {
            protein = weight * proteinPerKilo(for: goal)
        } else {
            protein = kcal * proteinShare(for: goal) / 4
        }
        let cappedProtein = min(protein, kcal * 0.35 / 4)
        let fat = kcal * 0.27 / 9
        let carbs = max(0, (kcal - 4 * cappedProtein - 9 * fat) / 4)

        return DailyTargets(kcal: Int(round(kcal, to: 50)),
                            protein: Int(round(cappedProtein, to: 5)),
                            carbs: Int(round(carbs, to: 5)),
                            fat: Int(round(fat, to: 5)),
                            isPersonal: isPersonal)
    }

    private static func adjustment(for goal: FitnessGoal, maintenance: Double) -> Double {
        switch goal {
        case .loseWeight: -min(500, maintenance * 0.15)
        case .gainWeight: 400
        case .buildMuscle: 250
        case .stayFit, .justCook: 0
        }
    }

    private static func minimumKcal(_ sex: BiologicalSex?) -> Double {
        switch sex {
        case .male?: 1_500
        case .female?: 1_200
        case nil: 1_400
        }
    }

    private static func proteinPerKilo(for goal: FitnessGoal) -> Double {
        switch goal {
        case .buildMuscle: 2.0
        case .loseWeight: 1.8
        case .gainWeight: 1.6
        case .stayFit, .justCook: 1.4
        }
    }

    /// Used when there's no body weight to work from.
    private static func proteinShare(for goal: FitnessGoal) -> Double {
        switch goal {
        case .buildMuscle, .loseWeight: 0.30
        case .gainWeight: 0.20
        case .stayFit, .justCook: 0.25
        }
    }

    private static func round(_ value: Double, to step: Double) -> Double {
        (value / step).rounded() * step
    }
}
