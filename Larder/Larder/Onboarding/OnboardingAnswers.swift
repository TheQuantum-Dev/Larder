//
//  OnboardingAnswers.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation
import Observation

/// What the person told us during onboarding. Held in memory until they finish,
/// when it's saved to their profile.
@Observable
final class OnboardingAnswers {
    var diets = MultiSelection<Diet>(exclusive: .noRestrictions)
    var cooking = MultiSelection<CookingConfidence>()
    var priorities = MultiSelection<Priority>()
    /// One goal at a time, since losing and gaining weight can't both be the plan.
    var goal = MultiSelection<FitnessGoal>(single: true)
    /// What the person confirmed having during the try-it scan.
    var pantry: [ResolvedItem] = []
    /// The recipe they picked to cook first.
    var firstRecipeID: String?
    /// What they chose on the paywall.
    var paywallOutcome: PaywallView.Outcome?

    var fitnessGoal: FitnessGoal? { goal.ordered.first }

    /// What recipe ranking needs while the person is still in onboarding,
    /// using a 2,000 kcal day since no body stats have been asked for yet.
    var goalContext: GoalContext? {
        guard let goal = fitnessGoal,
              let targets = NutritionTargets.targets(for: goal, stats: BodyStats()) else { return nil }
        return GoalContext(goal: goal, perMeal: targets.perMeal)
    }
}
