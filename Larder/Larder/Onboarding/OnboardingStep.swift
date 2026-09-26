//
//  OnboardingStep.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation

/// The screens of onboarding, in order.
enum OnboardingStep: Int, CaseIterable {
    case welcome, diet, cooking, priorities, goal, synthesis, tryIt, recipes, online, health, commitment, founderNote, paywall, notifications, allSet

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    /// The neighbouring screens, skipping the ones that don't apply: Apple Health
    /// for people who chose "just cook" (with no numbers to show, there's nothing
    /// to sync), and the online recipes question in a build that has no way to
    /// look them up.
    func next(showsNutrition: Bool, offersOnline: Bool = false) -> OnboardingStep? {
        var candidate = next
        while let step = candidate, step.isSkipped(showsNutrition: showsNutrition, offersOnline: offersOnline) {
            candidate = step.next
        }
        return candidate
    }

    func previous(showsNutrition: Bool, offersOnline: Bool = false) -> OnboardingStep? {
        var candidate = previous
        while let step = candidate, step.isSkipped(showsNutrition: showsNutrition, offersOnline: offersOnline) {
            candidate = step.previous
        }
        return candidate
    }

    private func isSkipped(showsNutrition: Bool, offersOnline: Bool) -> Bool {
        switch self {
        case .health: !showsNutrition
        case .online: !offersOnline
        default: false
        }
    }

    /// The bar never starts empty: the welcome screen counts as a finished step.
    var progress: Double { Double(rawValue + 1) / Double(Self.allCases.count) }

    /// The welcome, paywall, notifications and sign-off screens stand alone,
    /// with no bar or back button, so the paywall isn't crowded and nothing
    /// nags after it.
    var showsProgress: Bool { ![.welcome, .paywall, .notifications, .allSet].contains(self) }
}
