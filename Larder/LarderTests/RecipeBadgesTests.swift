//
//  RecipeBadgesTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/21/26.
//

import Testing
@testable import Larder

struct RecipeBadgesTests {
    private func match(minutes: Int = 30, healthy: Bool = false, servings: Int = 1,
                       ingredientCount: Int = 1, missingCount: Int = 0) -> RecipeMatch {
        let lines = (0..<ingredientCount).map { RecipeIngredient(id: "i\($0)", amount: "1", qty: 1, optional: nil, alt: nil) }
        let recipe = Recipe(id: "r", title: "r", emoji: "🍽️", minutes: minutes, servings: servings, equipment: [],
                            ingredients: lines, steps: [RecipeStep(text: "Cook.", timer: nil)], tip: "", healthy: healthy)
        return RecipeMatch(recipe: recipe, missing: Array(lines.suffix(missingCount)), required: ingredientCount)
    }

    @Test func nothingShowsWithoutAMatchingPriority() {
        let badges = RecipeBadges.reasons(for: match(), priorities: [], cooking: [])
        #expect(badges.isEmpty)
    }

    @Test func cheapOnlyShowsWhenSaveMoneyIsPickedAndTheRecipeIsCheap() {
        // A single generic ingredient costs nothing in IngredientPrices, so it's cheap.
        #expect(RecipeBadges.reasons(for: match(), priorities: [.saveMoney], cooking: []).contains("💸 Cheap"))
        #expect(!RecipeBadges.reasons(for: match(), priorities: [], cooking: []).contains("💸 Cheap"))
    }

    @Test func quickOnlyShowsForFastRecipesWhenAsked() {
        let quick = match(minutes: 10)
        let slow = match(minutes: 40)
        #expect(RecipeBadges.reasons(for: quick, priorities: [.fast], cooking: []).contains("⚡️ Quick"))
        #expect(!RecipeBadges.reasons(for: slow, priorities: [.fast], cooking: []).contains("⚡️ Quick"))
    }

    @Test func healthierOnlyShowsForRecipesTaggedHealthy() {
        let healthy = match(healthy: true)
        let treat = match(healthy: false)
        #expect(RecipeBadges.reasons(for: healthy, priorities: [.eatHealthier], cooking: []).contains("🥗 Healthier"))
        #expect(!RecipeBadges.reasons(for: treat, priorities: [.eatHealthier], cooking: []).contains("🥗 Healthier"))
    }

    @Test func usesYourPantryOnlyShowsWhenYouAlreadyHaveMostOfIt() {
        let mostlyStocked = match(ingredientCount: 5, missingCount: 1)
        let mostlyMissing = match(ingredientCount: 5, missingCount: 4)
        #expect(RecipeBadges.reasons(for: mostlyStocked, priorities: [.cutWaste], cooking: []).contains("♻️ Uses a lot of your pantry"))
        #expect(!RecipeBadges.reasons(for: mostlyMissing, priorities: [.cutWaste], cooking: []).contains("♻️ Uses a lot of your pantry"))
    }

    @Test func neverShowsMoreThanTwo() {
        let recipe = match(minutes: 5, healthy: true, ingredientCount: 5, missingCount: 0)
        let badges = RecipeBadges.reasons(for: recipe, priorities: [.saveMoney, .fast, .eatHealthier, .cutWaste], cooking: [])
        #expect(badges.count <= 2)
    }
}
