//
//  RecipeFormattingTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/21/26.
//

import Testing
@testable import Larder

@MainActor
struct RecipeFormattingTests {

    @Test func timersReadNaturally() {
        #expect(TimerText.text(seconds: 45) == "45 sec")
        #expect(TimerText.text(seconds: 300) == "5 min")
        #expect(TimerText.text(seconds: 90) == "1 min 30 sec")
        #expect(TimerText.text(seconds: 1500) == "25 min")
    }

    @Test func costsAreShownAsRoughDollarAmounts() {
        let friedRice = RecipeStore.recipe(withID: "egg-fried-rice")!
        #expect(friedRice.costText.hasPrefix("about $"))
        #expect(friedRice.costText.contains("."))
    }

    @Test func aDietHidesOptionalExtrasItRulesOut() {
        // Honey is an optional drizzle on the peanut butter toast.
        let toast = RecipeStore.recipe(withID: "pb-banana-toast")!
        #expect(toast.visibleIngredients(for: []).contains { $0.id == "honey" })
        #expect(!toast.visibleIngredients(for: [.vegan]).contains { $0.id == "honey" })
    }

    @Test func requiredIngredientsAreNeverHidden() {
        let toast = RecipeStore.recipe(withID: "pb-banana-toast")!
        let required = toast.ingredients.filter { !$0.isOptional }
        let visible = toast.visibleIngredients(for: [.vegan])
        #expect(required.allSatisfy { line in visible.contains { $0.id == line.id } })
    }
}
