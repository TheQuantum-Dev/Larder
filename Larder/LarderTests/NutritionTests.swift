//
//  NutritionTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/25/26.
//

import Testing
@testable import Larder

@MainActor
struct NutritionTests {
    private let recipes = RecipeStore.all
    /// Too small to matter, so a line for them doesn't need a weight.
    private let negligible: Set<String> = ["salt", "black-pepper", "water"]

    private func recipe(servings: Int = 1, lines: [RecipeIngredient]) -> Recipe {
        Recipe(id: "test", title: "Test", emoji: "🍽️", minutes: 10, servings: servings, equipment: [],
               ingredients: lines, steps: [RecipeStep(text: "Cook it.", timer: nil)], tip: "Enjoy.", healthy: false)
    }

    private func line(_ id: String, grams: Double?, nutri: String? = nil, optional: Bool? = nil) -> RecipeIngredient {
        RecipeIngredient(id: id, amount: id, qty: 1, optional: optional, alt: nil, grams: grams, nutri: nutri)
    }

    // MARK: - The table

    @Test func theTableLoadsWithSourceInformation() {
        #expect(NutritionTable.foods.count > 80)
        for (key, entry) in NutritionTable.foods {
            #expect(entry.fdc > 0, "\(key) has no FoodData Central id")
            #expect(!entry.food.isEmpty, "\(key) has no food name")
            #expect(entry.kcal >= 0 && entry.protein >= 0 && entry.carbs >= 0 && entry.fat >= 0, "\(key) has a negative value")
        }
    }

    @Test func aFewValuesMatchUSDA() throws {
        let chicken = try #require(NutritionTable.entry(for: "chicken"))
        #expect(chicken.kcal == 120 && chicken.protein == 22.5)
        let cooked = try #require(NutritionTable.entry(for: "rice-cooked"))
        #expect(cooked.kcal == 130)
        let oil = try #require(NutritionTable.entry(for: "cooking-oil"))
        #expect(oil.kcal == 884 && oil.fat == 100)
    }

    // MARK: - Recipe lines

    @Test func everyWeighedLineHasATableEntry() {
        for recipe in recipes {
            for line in recipe.ingredients where line.grams != nil {
                #expect(NutritionTable.entry(for: line.nutritionKey) != nil, "\(recipe.id): no nutrition for \(line.nutritionKey)")
            }
        }
    }

    @Test func everyRequiredLineHasAWeightUnlessItIsATrace() {
        for recipe in recipes {
            for line in recipe.ingredients where !line.isOptional && !negligible.contains(line.id) {
                #expect((line.grams ?? 0) > 0, "\(recipe.id): \(line.id) needs a weight in grams")
            }
        }
    }

    // MARK: - Recipe totals

    @Test func everyRecipeLooksLikeARealMeal() {
        for recipe in recipes {
            let m = recipe.nutrition
            #expect((150...1_100).contains(m.kcal), "\(recipe.id): \(Int(m.kcal)) kcal per serving looks wrong")
            #expect((3...90).contains(m.protein), "\(recipe.id): \(Int(m.protein)) g protein looks wrong")
        }
    }

    @Test func macrosAddUpToAboutTheCalories() {
        for recipe in recipes {
            let m = recipe.nutrition
            let fromMacros = 4 * m.protein + 4 * m.carbs + 9 * m.fat
            #expect(abs(fromMacros - m.kcal) <= 0.2 * m.kcal,
                    "\(recipe.id): macros give \(Int(fromMacros)) kcal but energy says \(Int(m.kcal))")
        }
    }

    @Test func aKnownRecipeComesOutRight() throws {
        // 158 g cooked rice, 100 g egg, 70 g peas and carrots, 16 g soy sauce, 14 g oil.
        let fried = try #require(RecipeStore.recipe(withID: "egg-fried-rice"))
        #expect(abs(fried.nutrition.kcal - 518) < 5)
        #expect(abs(fried.nutrition.protein - 21) < 1)
    }

    @Test func aTwoServingRecipeIsSharedOut() throws {
        let skillet = try #require(RecipeStore.recipe(withID: "chicken-rice-skillet"))
        #expect(skillet.servings == 2)
        // 200 g raw chicken alone is 240 kcal and 45 g protein; per serving that is half.
        #expect(skillet.nutrition.protein > 22 && skillet.nutrition.protein < 30)
    }

    @Test func oilIsCountedEvenThoughItIsAFreeStaple() {
        let withOil = recipe(lines: [line("egg", grams: 100), line("cooking-oil", grams: 14)])
        let without = recipe(lines: [line("egg", grams: 100)])
        #expect(abs((withOil.nutrition.kcal - without.nutrition.kcal) - 124) < 1)
    }

    @Test func optionalExtrasAndUnweighedLinesAreLeftOut() {
        let plain = recipe(lines: [line("egg", grams: 100)])
        let extras = recipe(lines: [line("egg", grams: 100), line("olive-oil", grams: 14, optional: true),
                                    line("salt", grams: nil)])
        #expect(plain.nutrition == extras.nutrition)
    }

    @Test func aNamedVariantOverridesTheIngredient() {
        let dry = recipe(lines: [line("rice", grams: 100)])
        let cooked = recipe(lines: [line("rice", grams: 100, nutri: "rice-cooked")])
        #expect(dry.nutrition.kcal == 365)
        #expect(cooked.nutrition.kcal == 130)
    }

    // MARK: - Arithmetic and text

    @Test func macrosAddAndScale() {
        let a = Macros(kcal: 100, protein: 10, carbs: 20, fat: 5)
        let b = Macros(kcal: 50, protein: 5, carbs: 5, fat: 2)
        #expect(a + b == Macros(kcal: 150, protein: 15, carbs: 25, fat: 7))
        #expect(a * 2 == Macros(kcal: 200, protein: 20, carbs: 40, fat: 10))
    }

    @Test func caloriesAreRoundedToTheNearestTen() {
        #expect(Macros(kcal: 518).roundedKcal == 520)
        #expect(Macros(kcal: 514).roundedKcal == 510)
        #expect(Macros(kcal: 518, protein: 20.6).summaryText == "520 kcal · 21 g protein")
    }
}
