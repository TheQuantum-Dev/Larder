//
//  OnboardingStep.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation

/// The screens of onboarding, in order.
enum OnboardingStep: Int, CaseIterable {
    case welcome, diet, cooking, priorities, goal, synthesis, tryIt, recipes, health, commitment, founderNote, paywall, notifications, allSet

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    /// The neighbouring screens, skipping Apple Health for people who chose
    /// "just cook": with no numbers to show, there's nothing to sync.
    func next(showsNutrition: Bool) -> OnboardingStep? {
        guard let next else { return nil }
        return next == .health && !showsNutrition ? next.next : next
    }

    func previous(showsNutrition: Bool) -> OnboardingStep? {
        guard let previous else { return nil }
        return previous == .health && !showsNutrition ? previous.previous : previous
    }

    /// The bar never starts empty: the welcome screen counts as a finished step.
    var progress: Double { Double(rawValue + 1) / Double(Self.allCases.count) }

    /// The welcome, paywall, notifications and sign-off screens stand alone,
    /// with no bar or back button, so the paywall isn't crowded and nothing
    /// nags after it.
    var showsProgress: Bool { ![.welcome, .paywall, .notifications, .allSet].contains(self) }
}
