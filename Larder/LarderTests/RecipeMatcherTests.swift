//
//  RecipeMatcherTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/21/26.
//

import Testing
@testable import Larder

@MainActor
struct RecipeMatcherTests {

    private func match(_ id: String, in matches: [RecipeMatch]) -> RecipeMatch? {
        matches.first { $0.recipe.id == id }
    }

    /// A tiny recipe for testing rules without depending on the bundled data.
    private func recipe(_ id: String, minutes: Int = 10, lines: [RecipeIngredient]) -> Recipe {
        Recipe(id: id, title: id, emoji: "🍽️", minutes: minutes, servings: 1, equipment: [],
               ingredients: lines, steps: [RecipeStep(text: "Cook it.", timer: nil)], tip: "Enjoy.")
    }

    private func line(_ id: String, qty: Double = 1, optional: Bool? = nil, alt: [String]? = nil) -> RecipeIngredient {
        RecipeIngredient(id: id, amount: id, qty: qty, optional: optional, alt: alt)
    }

    // MARK: - Ready or missing

    @Test func aFullPantryMakesARecipeReady() {
        let matches = RecipeMatcher.matches(pantry: ["rice", "egg", "frozen-veg", "soy-sauce"])
        #expect(match("egg-fried-rice", in: matches)?.isReady == true)
    }

    @Test func missingIngredientsAreListed() {
        let matches = RecipeMatcher.matches(pantry: ["rice", "egg", "soy-sauce"])
        let fried = match("egg-fried-rice", in: matches)
        #expect(fried?.isReady == false)
        #expect(fried?.missing.map(\.id) == ["frozen-veg"])
    }

    @Test func aSwapCountsAsHavingTheIngredient() {
        // Peas stand in for the frozen vegetables.
        let matches = RecipeMatcher.matches(pantry: ["rice", "egg", "peas", "soy-sauce"])
        #expect(match("egg-fried-rice", in: matches)?.isReady == true)
    }

    @Test func saltOilPepperAndWaterAreAssumed() {
        let recipes = [recipe("simple", lines: [line("egg"), line("salt", qty: 0), line("cooking-oil", qty: 0), line("water", qty: 0)])]
        let matches = RecipeMatcher.matches(recipes: recipes, pantry: ["egg"])
        #expect(matches.first?.isReady == true)
    }

    @Test func optionalIngredientsNeverBlockARecipe() {
        let recipes = [recipe("simple", lines: [line("egg"), line("cheese", optional: true)])]
        #expect(RecipeMatcher.matches(recipes: recipes, pantry: ["egg"]).first?.isReady == true)
    }

    @Test func recipesMissingTooMuchAreLeftOut() {
        let recipes = [recipe("far", lines: [line("egg"), line("rice"), line("beans"), line("cheese"), line("tomato")])]
        #expect(RecipeMatcher.matches(recipes: recipes, pantry: ["egg"], maxMissing: 3).isEmpty)
        #expect(RecipeMatcher.matches(recipes: recipes, pantry: ["egg"], maxMissing: 4).count == 1)
    }

    // MARK: - Diets

    @Test func vegetarianHidesMeatEvenWhenThePantryHasIt() {
        let pantry: Set<String> = ["chicken", "rice", "onion", "garlic"]
        #expect(match("chicken-rice-skillet", in: RecipeMatcher.matches(pantry: pantry)) != nil)
        #expect(match("chicken-rice-skillet", in: RecipeMatcher.matches(pantry: pantry, diets: [.vegetarian])) == nil)
    }

    @Test func aSwapTheDietRulesOutNeverCounts() {
        // Rice can be swapped for pasta, but pasta has gluten.
        let recipes = [recipe("bowl", lines: [line("rice", alt: ["pasta"])])]
        #expect(RecipeMatcher.matches(recipes: recipes, pantry: ["pasta"], diets: []).first?.isReady == true)
        #expect(RecipeMatcher.matches(recipes: recipes, pantry: ["pasta"], diets: [.glutenFree]).first?.isReady == false)
        #expect(RecipeMatcher.matches(recipes: recipes, pantry: ["rice"], diets: [.glutenFree]).first?.isReady == true)
    }

    // MARK: - Ordering

    @Test func readyRecipesComeBeforeAlmostReadyOnes() {
        let recipes = [
            recipe("almost", lines: [line("egg"), line("rice")]),
            recipe("ready", lines: [line("egg")]),
        ]
        let ids = RecipeMatcher.matches(recipes: recipes, pantry: ["egg"]).map(\.recipe.id)
        #expect(ids == ["ready", "almost"])
    }

    @Test func fewerMissingItemsRankHigher() {
        let recipes = [
            recipe("two-missing", lines: [line("egg"), line("rice"), line("beans")]),
            recipe("one-missing", lines: [line("egg"), line("rice")]),
        ]
        let ids = RecipeMatcher.matches(recipes: recipes, pantry: ["egg"]).map(\.recipe.id)
        #expect(ids == ["one-missing", "two-missing"])
    }

    @Test func whenNothingElseSeparatesThemTheCheaperRecipeComesFirst() {
        let recipes = [
            recipe("pricey", lines: [line("avocado", qty: 2)]),
            recipe("cheap", lines: [line("egg")]),
        ]
        let ids = RecipeMatcher.matches(recipes: recipes, pantry: ["avocado", "egg"]).map(\.recipe.id)
        #expect(ids == ["cheap", "pricey"])
    }

    @Test func savingMoneyPutsTheCheaperRecipeFirst() {
        let recipes = [
            recipe("pricey", lines: [line("avocado", qty: 2)]),
            recipe("cheap", lines: [line("egg")]),
        ]
        let pantry: Set<String> = ["avocado", "egg"]
        let cheapFirst = RecipeMatcher.matches(recipes: recipes, pantry: pantry, priorities: [.saveMoney]).map(\.recipe.id)
        #expect(cheapFirst == ["cheap", "pricey"])
    }

    @Test func wantingItFastPutsTheQuickerRecipeFirst() {
        let recipes = [
            recipe("slow", minutes: 45, lines: [line("egg")]),
            recipe("quick", minutes: 5, lines: [line("egg")]),
        ]
        let ids = RecipeMatcher.matches(recipes: recipes, pantry: ["egg"], priorities: [.fast]).map(\.recipe.id)
        #expect(ids == ["quick", "slow"])
    }

    // MARK: - Never a dead end

    @Test func nothingCloseWidensTheSearchInsteadOfShowingNothing() {
        // Five things missing is too far for the normal search but fine for the wider one.
        let recipes = [recipe("big", lines: [line("egg"), line("rice"), line("beans"), line("cheese"), line("tomato")])]
        let result = RecipeMatcher.bestMatches(recipes: recipes, pantry: [])
        #expect(result.stretched)
        #expect(result.matches.count == 1)
    }

    @Test func closeRecipesAreNotStretched() {
        let recipes = [recipe("easy", lines: [line("egg")])]
        let result = RecipeMatcher.bestMatches(recipes: recipes, pantry: ["egg"])
        #expect(!result.stretched)
        #expect(result.matches.count == 1)
    }

    @Test func aRealStudentDietStillGetsSomethingWithAnEmptyPantry() {
        let result = RecipeMatcher.bestMatches(pantry: [], diets: [.vegan, .glutenFree, .nutFree])
        #expect(!result.matches.isEmpty)
    }

    // MARK: - With the real recipes

    @Test func aTypicalStudentPantryHasSomethingToCook() {
        let pantry: Set<String> = ["egg", "rice", "pasta", "tomato-sauce", "onion", "garlic", "cheese", "bread", "butter", "milk"]
        let ready = RecipeMatcher.matches(pantry: pantry).filter(\.isReady)
        #expect(ready.count >= 3)
    }

    @Test func aNearlyEmptyPantryStillGetsSuggestions() {
        // Nothing should ever be a dead end: with almost nothing, recipes that
        // are only a few items away still show up.
        let matches = RecipeMatcher.matches(pantry: ["egg"], maxMissing: 3)
        #expect(!matches.isEmpty)
    }
}
