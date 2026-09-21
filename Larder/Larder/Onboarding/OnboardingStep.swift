//
//  OnboardingStep.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation

/// The screens of onboarding, in order. Later steps (commitment, founder
/// note, paywall) get added to this list.
enum OnboardingStep: Int, CaseIterable {
    case welcome, diet, cooking, priorities, synthesis, tryIt, recipes

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    /// The bar never starts empty: the welcome screen counts as a finished step.
    var progress: Double { Double(rawValue + 1) / Double(Self.allCases.count) }

    var showsProgress: Bool { self != .welcome }
}
