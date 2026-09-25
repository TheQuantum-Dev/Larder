//
//  NutmegLookTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation
import Testing
@testable import Larder

struct NutmegLookTests {
    @Test func nothingIsEarnedAtTheStart() {
        #expect(NutmegLook.earned(bestStreak: 0, mealCount: 0).isEmpty)
        #expect(NutmegLook.earned(bestStreak: 2, mealCount: 4).isEmpty)
    }

    @Test func coralIsEarnedByAThreeDayStreakOrFiveMeals() {
        #expect(NutmegLook.earned(bestStreak: 3, mealCount: 3) == [.coral])
        #expect(NutmegLook.earned(bestStreak: 1, mealCount: 5) == [.coral])
    }

    @Test func amberIsAlwaysThereAndTheRestHaveToBeGot() {
        #expect(NutmegLook.amber.isAvailable(earned: [], hasPlus: false))
        #expect(!NutmegLook.coral.isAvailable(earned: [], hasPlus: true), "earning can't be bought")
        #expect(NutmegLook.coral.isAvailable(earned: [.coral], hasPlus: false), "earned looks stay free")
        #expect(!NutmegLook.snow.isAvailable(earned: [.coral], hasPlus: false))
        #expect(NutmegLook.snow.isAvailable(earned: [], hasPlus: true))
        #expect(NutmegLook.harvest.isAvailable(earned: [], hasPlus: true))
    }

    @Test func aPlusLookQuietlyGoesBackToAmberWithoutPlus() {
        #expect(NutmegLook.snow.effective(hasPlus: false) == .amber)
        #expect(NutmegLook.snow.effective(hasPlus: true) == .snow)
        #expect(NutmegLook.coral.effective(hasPlus: false) == .coral, "an earned look isn't taken away")
    }

    @Test func onlyTheSeasonalLooksAreForPlus() {
        #expect(NutmegLook.allCases.filter(\.isPlus) == [.snow, .harvest])
    }

    @Test func earnedLooksSayHowToGetThem() {
        #expect(NutmegLook.coral.unlockHint == "Cook 5 meals or keep a 3-day streak")
        #expect(NutmegLook.amber.unlockHint == nil)
    }

    @Test func everyLookButAmberHasItsOwnUniqueIcon() {
        #expect(NutmegLook.amber.iconName == nil)
        let names = NutmegLook.allCases.compactMap(\.iconName)
        #expect(names.count == 3 && Set(names).count == 3)
    }

    @Test func everyAlternateIconIsActuallyInTheApp() {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let listed = (icons?["CFBundleAlternateIcons"] as? [String: Any]).map { Set($0.keys) } ?? []
        #expect(listed == Set(NutmegLook.allCases.compactMap(\.iconName)))
    }
}
