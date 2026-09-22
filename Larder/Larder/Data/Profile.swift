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
nonisolated struct Profile: Codable, Equatable, Sendable {
    var diets: [String] = []
    var cooking: [String] = []
    var priorities: [String] = []

    init() {}

    init(diets: Set<Diet>, cooking: Set<CookingConfidence>, priorities: Set<Priority>) {
        self.diets = diets.map(\.rawValue).sorted()
        self.cooking = cooking.map(\.rawValue).sorted()
        self.priorities = priorities.map(\.rawValue).sorted()
    }

    var dietSet: Set<Diet> { Set(diets.compactMap(Diet.init(rawValue:))) }
    var cookingSet: Set<CookingConfidence> { Set(cooking.compactMap(CookingConfidence.init(rawValue:))) }
    var prioritySet: Set<Priority> { Set(priorities.compactMap(Priority.init(rawValue:))) }
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
