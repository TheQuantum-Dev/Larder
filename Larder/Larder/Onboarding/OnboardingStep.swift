//
//  OnboardingStep.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation

/// The screens of onboarding, in order.
enum OnboardingStep: Int, CaseIterable {
    case welcome, diet, cooking, priorities, synthesis, tryIt, recipes, commitment, founderNote, paywall, allSet

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    /// The bar never starts empty: the welcome screen counts as a finished step.
    var progress: Double { Double(rawValue + 1) / Double(Self.allCases.count) }

    /// The welcome, paywall and sign-off screens stand alone, with no bar or back
    /// button, so the paywall isn't crowded and nothing nags after it.
    var showsProgress: Bool { ![.welcome, .paywall, .allSet].contains(self) }
}
