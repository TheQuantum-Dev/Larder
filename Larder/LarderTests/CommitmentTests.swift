//
//  CommitmentTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/21/26.
//

import Testing
@testable import Larder

struct CommitmentTests {

    @Test func budgetMovesInSteps() {
        #expect(Commitment.adjustedBudget(50, steps: 1) == 55)
        #expect(Commitment.adjustedBudget(50, steps: -2) == 40)
    }

    @Test func budgetStaysInsideItsRange() {
        #expect(Commitment.adjustedBudget(10, steps: -1) == 10)
        #expect(Commitment.adjustedBudget(300, steps: 1) == 300)
        #expect(Commitment.adjustedBudget(295, steps: 5) == 300)
    }

    @Test func theSuggestedStartsAreOfferedChoices() {
        #expect(Commitment.mealGoals.contains(Commitment.defaultMealGoal))
        #expect(Commitment.budgetRange.contains(Commitment.suggestedBudget))
    }

    @Test func mealsThisWeekReadsWithOrWithoutAGoal() {
        #expect(Commitment.mealsThisWeekText(count: 2, goal: 3) == "2 of 3")
        #expect(Commitment.mealsThisWeekText(count: 2, goal: 0) == "2")
    }
}

struct OnboardingStepTests {

    @Test func theEndingScreensStandAloneWithoutAProgressBar() {
        #expect(!OnboardingStep.welcome.showsProgress)
        #expect(!OnboardingStep.paywall.showsProgress)
        #expect(!OnboardingStep.notifications.showsProgress)
        #expect(!OnboardingStep.allSet.showsProgress)
        #expect(OnboardingStep.commitment.showsProgress)
        #expect(OnboardingStep.founderNote.showsProgress)
    }

    @Test func theFlowIsInTheDesignedOrder() {
        let tail = Array(OnboardingStep.allCases.suffix(7))
        #expect(tail == [.tryIt, .recipes, .commitment, .founderNote, .paywall, .notifications, .allSet])
    }

    @Test func theFounderNoteComesRightBeforeThePaywall() {
        #expect(OnboardingStep.founderNote.next == .paywall)
    }

    @Test func notificationsAreAskedAboutAfterThePaywallNotBefore() {
        #expect(OnboardingStep.paywall.next == .notifications)
        #expect(OnboardingStep.notifications.next == .allSet)
    }
}
