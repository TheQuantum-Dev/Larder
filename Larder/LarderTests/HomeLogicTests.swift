//
//  HomeLogicTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation
import SwiftData
import Testing
@testable import Larder

struct ProfileTests {
    private func freshDefaults() -> UserDefaults {
        let name = "larder-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func aProfileSurvivesSavingAndLoading() {
        let defaults = freshDefaults()
        let profile = Profile(diets: [.vegetarian, .glutenFree], cooking: [.followRecipe], priorities: [.saveMoney, .fast])
        ProfileStore.save(profile, to: defaults)
        let loaded = ProfileStore.load(from: defaults)
        #expect(loaded == profile)
        #expect(loaded.dietSet == [.vegetarian, .glutenFree])
        #expect(loaded.cookingSet == [.followRecipe])
        #expect(loaded.prioritySet == [.saveMoney, .fast])
    }

    @Test func nothingSavedMeansNoRestrictions() {
        let loaded = ProfileStore.load(from: freshDefaults())
        #expect(loaded.dietSet.isEmpty)
        #expect(loaded.cookingSet.isEmpty)
        #expect(loaded.prioritySet.isEmpty)
    }

    @Test func unknownNamesInSavedDataAreIgnoredNotFatal() {
        var profile = Profile()
        profile.diets = ["vegan", "someFutureDiet"]
        #expect(profile.dietSet == [.vegan])
    }
}

struct HomeGreetingTests {
    @Test func anEmptyPantryIsInvitedToFillUp() {
        #expect(HomeGreeting.text(pantryCount: 0, readyCount: 0).contains("fill it up"))
    }

    @Test func thereIsAlwaysSomethingToSay() {
        #expect(HomeGreeting.text(pantryCount: 5, readyCount: 0).contains("close"))
        #expect(HomeGreeting.text(pantryCount: 5, readyCount: 1) == "You can make 1 thing right now.")
        #expect(HomeGreeting.text(pantryCount: 5, readyCount: 4) == "You can make 4 things right now.")
    }
}

@MainActor
struct PantryAddTests {
    @Test func addingKeepsWhatIsAlreadyThereAndSkipsDuplicates() throws {
        let db = try TestDatabase()
        let egg = IngredientCatalog.resolve("egg")!
        let rice = IngredientCatalog.resolve("rice")!
        PantryRepository.replace(with: [egg], in: db.context)
        PantryRepository.add([egg, rice], in: db.context)
        #expect(Set(PantryRepository.all(in: db.context).map(\.ingredientID)) == ["egg", "rice"])
        #expect(PantryRepository.all(in: db.context).count == 2)
    }
}
