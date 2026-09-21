//
//  OnboardingAnswers.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation
import Observation

/// What the person told us during onboarding. Held in memory for now; it moves
/// into SwiftData with the rest of the profile.
@Observable
final class OnboardingAnswers {
    var diets = MultiSelection<Diet>(exclusive: .noRestrictions)
    var cooking = MultiSelection<CookingConfidence>()
    var priorities = MultiSelection<Priority>()
    /// What the person confirmed having during the try-it scan.
    var pantry: [ResolvedItem] = []
}
