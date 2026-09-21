//
//  Commitment.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

/// The small weekly goal set near the end of onboarding: how many meals to
/// cook from the pantry, and, for people who said they want to save money, a
/// weekly food budget. It's a target to aim for, never a rule.
nonisolated enum Commitment {
    static let mealGoals = [2, 3, 5, 7]
    static let defaultMealGoal = 3

    static let budgetRange = 10...300
    static let budgetStep = 5
    /// Where the budget picker starts. It's a starting point, not advice.
    static let suggestedBudget = 50

    /// The budget after tapping plus or minus, kept inside the allowed range.
    static func adjustedBudget(_ current: Int, steps: Int) -> Int {
        min(max(current + steps * budgetStep, budgetRange.lowerBound), budgetRange.upperBound)
    }

    /// "2 of 3" when there's a goal, just "2" when there isn't.
    static func mealsThisWeekText(count: Int, goal: Int) -> String {
        goal > 0 ? "\(count) of \(goal)" : "\(count)"
    }
}
