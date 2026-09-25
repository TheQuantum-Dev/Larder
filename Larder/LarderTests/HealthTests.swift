//
//  HealthTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation
import HealthKit
import Testing
@testable import Larder

struct HealthMealTests {
    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func theSameMealAlwaysGetsTheSameID() {
        let a = HealthMeal(recipeID: "egg-fried-rice", title: "Egg fried rice", date: date, macros: Macros(kcal: 518))
        let b = HealthMeal(recipeID: "egg-fried-rice", title: "Egg fried rice", date: date, macros: Macros(kcal: 300))
        #expect(a.syncID == b.syncID)
        #expect(a.syncID != HealthMeal(recipeID: "egg-fried-rice", title: "x", date: date.addingTimeInterval(60), macros: .zero).syncID)
    }

    @Test func fourNutrientsInTheUnitsHealthWants() {
        let entries = HealthNutrients.entries(for: Macros(kcal: 520, protein: 21, carbs: 54, fat: 24))
        #expect(entries.map(\.identifier) == HealthNutrients.identifiers)
        #expect(entries.map(\.value) == [520, 21, 54, 24])
        #expect(entries[0].unit == HKUnit.kilocalorie())
        #expect(entries[1...].allSatisfy { $0.unit == HKUnit.gram() })
    }

    @Test func aStandInDoesNothingAndNeverFails() async {
        let health: any HealthSync = NoOpHealthSync()
        #expect(!health.isAvailable)
        await health.requestAccess()
        await health.logMeal(HealthMeal(recipeID: "r", title: "r", date: date, macros: .zero))
        #expect(await health.readBodyStats() == BodyStats())
    }
}

struct ProfileHealthMergeTests {
    private let fromHealth = BodyStats(birthYear: 2005, sex: .female, heightCm: 168, weightKg: 61)

    @Test func healthFillsWhatIsEmpty() {
        var profile = Profile()
        profile.merge(fromHealth, overwrite: false)
        #expect(profile.birthYear == 2005 && profile.sex == "female")
        #expect(profile.heightCm == 168 && profile.weightKg == 61)
    }

    @Test func numbersAlreadyEnteredAreKeptUnlessAskedToOverwrite() {
        var profile = Profile()
        profile.weightKg = 70
        profile.merge(fromHealth, overwrite: false)
        #expect(profile.weightKg == 70)
        profile.merge(fromHealth, overwrite: true)
        #expect(profile.weightKg == 61)
    }

    @Test func whatHealthDoesntHaveIsNeverWiped() {
        var profile = Profile()
        profile.heightCm = 180
        profile.merge(BodyStats(weightKg: 75), overwrite: true)
        #expect(profile.heightCm == 180 && profile.weightKg == 75)
    }
}

struct OnboardingHealthStepTests {
    @Test func healthComesRightAfterTheFirstRecipeAndBeforeTheCommitment() {
        #expect(OnboardingStep.recipes.next == .health)
        #expect(OnboardingStep.health.next == .commitment)
        #expect(OnboardingStep.health.showsProgress)
    }

    @Test func justCookSkipsHealthBothWays() {
        #expect(OnboardingStep.recipes.next(showsNutrition: false) == .commitment)
        #expect(OnboardingStep.commitment.previous(showsNutrition: false) == .recipes)
    }

    @Test func everyoneElseSeesHealth() {
        #expect(OnboardingStep.recipes.next(showsNutrition: true) == .health)
        #expect(OnboardingStep.commitment.previous(showsNutrition: true) == .health)
        #expect(OnboardingStep.welcome.previous(showsNutrition: true) == nil)
        #expect(OnboardingStep.allSet.next(showsNutrition: true) == nil)
    }
}
