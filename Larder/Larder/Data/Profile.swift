//
//  Profile.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

/// What the person told us about how they eat, kept so recipes stay matched
/// to them after onboarding is over. Stored by name, so adding a new option
/// later doesn't break what's already saved.
///
/// Anything added after the first version must be optional: a saved profile
/// that's missing a new key still decodes, instead of throwing and silently
/// wiping the diets and priorities it does have.
nonisolated struct Profile: Codable, Equatable, Sendable {
    var diets: [String] = []
    var cooking: [String] = []
    var priorities: [String] = []
    var goal: String?
    var birthYear: Int?
    var sex: String?
    var heightCm: Double?
    var weightKg: Double?
    var activity: String?

    init() {}

    init(diets: Set<Diet>, cooking: Set<CookingConfidence>, priorities: Set<Priority>, goal: FitnessGoal? = nil) {
        update(diets: diets, cooking: cooking, priorities: priorities, goal: goal)
    }

    /// Replaces the answers from the quiz and leaves everything else, like body
    /// stats set later in Settings, alone.
    mutating func update(diets: Set<Diet>, cooking: Set<CookingConfidence>, priorities: Set<Priority>,
                         goal: FitnessGoal?) {
        self.diets = diets.map(\.rawValue).sorted()
        self.cooking = cooking.map(\.rawValue).sorted()
        self.priorities = priorities.map(\.rawValue).sorted()
        self.goal = goal?.rawValue
    }

    var dietSet: Set<Diet> { Set(diets.compactMap(Diet.init(rawValue:))) }
    var cookingSet: Set<CookingConfidence> { Set(cooking.compactMap(CookingConfidence.init(rawValue:))) }
    var prioritySet: Set<Priority> { Set(priorities.compactMap(Priority.init(rawValue:))) }

    var fitnessGoal: FitnessGoal? { goal.flatMap(FitnessGoal.init(rawValue:)) }

    /// Recipes show calories and macros unless the person chose "just cook".
    /// People who haven't picked a goal yet still see them on recipes.
    var showsNutrition: Bool { fitnessGoal?.showsNutrition ?? true }

    var bodyStats: BodyStats {
        get {
            BodyStats(birthYear: birthYear, sex: sex.flatMap(BiologicalSex.init(rawValue:)),
                      heightCm: heightCm, weightKg: weightKg,
                      activity: activity.flatMap(ActivityLevel.init(rawValue:)) ?? .light)
        }
        set {
            birthYear = newValue.birthYear
            sex = newValue.sex?.rawValue
            heightCm = newValue.heightCm
            weightKg = newValue.weightKg
            activity = newValue.activity.rawValue
        }
    }

    /// A day's calories and macros for the goal, or nil with no goal or "just cook".
    var dailyTargets: DailyTargets? {
        fitnessGoal.flatMap { NutritionTargets.targets(for: $0, stats: bodyStats) }
    }

    /// What recipe ranking needs to favour the goal.
    var goalContext: GoalContext? {
        guard let goal = fitnessGoal, let targets = dailyTargets else { return nil }
        return GoalContext(goal: goal, perMeal: targets.perMeal)
    }
}

nonisolated enum ProfileStore {
    static let key = "profile"

    static func load(from defaults: UserDefaults = .standard) -> Profile {
        guard let data = defaults.data(forKey: key),
              let profile = try? JSONDecoder().decode(Profile.self, from: data) else { return Profile() }
        return profile
    }

    static func save(_ profile: Profile, to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: key)
        }
    }
}
