//
//  DataTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation
import SwiftData
import Testing
@testable import Larder

/// An empty, throwaway database that lives only for the length of one test.
@MainActor
final class TestDatabase {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: PantryItem.self, CookedMeal.self, ShoppingItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}

@MainActor
struct PantryRepositoryTests {
    private let egg = IngredientCatalog.resolve("egg")!
    private let rice = IngredientCatalog.resolve("rice")!
    private let milk = IngredientCatalog.resolve("milk")!

    @Test func savesAndReadsBackThePantry() throws {
        let db = try TestDatabase()
        PantryRepository.replace(with: [egg, rice], in: db.context)
        #expect(Set(PantryRepository.all(in: db.context).map(\.ingredientID)) == ["egg", "rice"])
    }

    @Test func replacingSwapsTheWholePantry() throws {
        let db = try TestDatabase()
        PantryRepository.replace(with: [egg, rice], in: db.context)
        PantryRepository.replace(with: [rice, milk], in: db.context)
        #expect(Set(PantryRepository.all(in: db.context).map(\.ingredientID)) == ["rice", "milk"])
    }

    @Test func replacingWithTheSameItemsDoesNotDuplicateThem() throws {
        let db = try TestDatabase()
        PantryRepository.replace(with: [egg], in: db.context)
        PantryRepository.replace(with: [egg], in: db.context)
        #expect(PantryRepository.all(in: db.context).count == 1)
    }

    @Test func removingTakesOnlyTheNamedItems() throws {
        let db = try TestDatabase()
        PantryRepository.replace(with: [egg, rice, milk], in: db.context)
        PantryRepository.remove(ids: ["egg", "milk"], in: db.context)
        #expect(PantryRepository.all(in: db.context).map(\.ingredientID) == ["rice"])
    }

    @Test func customItemsKeepTheirNameAndFlag() throws {
        let db = try TestDatabase()
        let custom = ResolvedItem(customName: "dragon fruit")
        PantryRepository.replace(with: [custom], in: db.context)
        let saved = PantryRepository.all(in: db.context).first?.resolved
        #expect(saved?.isCustom == true)
        #expect(saved?.name == "Dragon fruit")
    }

    @Test func anEmptyPantryIsFine() throws {
        let db = try TestDatabase()
        PantryRepository.replace(with: [], in: db.context)
        #expect(PantryRepository.all(in: db.context).isEmpty)
    }
}

@MainActor
struct MealLogTests {
    private func summary(_ id: String = "egg-fried-rice", orderOut: Double = 14) -> MealSummary {
        MealSummary(recipe: RecipeStore.recipe(withID: id)!, orderOutPrice: orderOut)
    }

    // MARK: - The money

    @Test func aMealSavesTheGapBetweenOrderingOutAndCooking() {
        let s = summary()
        #expect(s.servings == 1)
        #expect(abs(s.totalCost - s.costPerServing) < 0.0001)
        #expect(abs(s.saved - (14 - s.costPerServing)) < 0.0001)
    }

    @Test func aTwoServingRecipeCountsBothServings() {
        let s = summary("lentil-soup")   // serves 2
        #expect(s.servings == 2)
        #expect(abs(s.orderOutTotal - 28) < 0.0001)
        #expect(abs(s.totalCost - s.costPerServing * 2) < 0.0001)
    }

    @Test func savingsNeverGoBelowZero() {
        // If ordering out were somehow cheaper, we say nothing was saved.
        #expect(summary(orderOut: 0.10).saved == 0)
    }

    @Test func moneyReadsAsRoughDollars() {
        #expect(Money.text(12.7) == "$12.70")
        #expect(Money.about(1.3) == "about $1.30")
    }

    // MARK: - Recording

    @Test func recordingAMealSavesIt() throws {
        let db = try TestDatabase()
        #expect(MealLog.count(in: db.context) == 0)
        MealLog.record(summary(), in: db.context)
        #expect(MealLog.count(in: db.context) == 1)
        #expect(MealLog.meals(in: db.context).first?.recipeID == "egg-fried-rice")
    }

    @Test func statsAddUpMealsAndSavings() throws {
        let db = try TestDatabase()
        let s = summary()
        MealLog.record(s, in: db.context)
        MealLog.record(s, in: db.context)
        let stats = MealStats.compute(from: MealLog.meals(in: db.context))
        #expect(stats.mealCount == 2)
        #expect(stats.mealsThisWeek == 2)
        #expect(abs(stats.totalSaved - s.saved * 2) < 0.0001)
    }

    @Test func onlyMealsFromThisWeekCountForThisWeek() throws {
        let db = try TestDatabase()
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2   // weeks start on Monday
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 12))!
        let lastWeek = calendar.date(byAdding: .day, value: -8, to: wednesday)!
        let earlierThisWeek = calendar.date(byAdding: .day, value: -2, to: wednesday)!

        MealLog.record(summary(), at: lastWeek, in: db.context)
        MealLog.record(summary(), at: earlierThisWeek, in: db.context)

        let stats = MealStats.compute(from: MealLog.meals(in: db.context), now: wednesday, calendar: calendar)
        #expect(stats.mealCount == 2)
        #expect(stats.mealsThisWeek == 1)
    }
}

struct PantryUseTests {
    @Test func listsThePantryIngredientsARecipeUses() {
        let recipe = RecipeStore.recipe(withID: "egg-fried-rice")!
        let used = PantryUse.usedIngredientIDs(by: recipe, pantry: ["rice", "egg", "soy-sauce", "frozen-veg", "milk", "bread"])
        #expect(used == ["rice", "egg", "frozen-veg", "soy-sauce"])
    }

    @Test func ignoresIngredientsThePantryLacks() {
        let recipe = RecipeStore.recipe(withID: "egg-fried-rice")!
        #expect(PantryUse.usedIngredientIDs(by: recipe, pantry: ["egg"]) == ["egg"])
    }

    @Test func aSwapInThePantryCountsAsTheIngredientUsed() {
        // Peas were used in place of the frozen vegetables.
        let recipe = RecipeStore.recipe(withID: "egg-fried-rice")!
        let used = PantryUse.usedIngredientIDs(by: recipe, pantry: ["rice", "peas"])
        #expect(used.contains("peas"))
    }

    @Test func staplesAndOptionalExtrasAreNeverListed() {
        let recipe = RecipeStore.recipe(withID: "egg-fried-rice")!
        let used = PantryUse.usedIngredientIDs(by: recipe, pantry: ["onion", "garlic", "cooking-oil", "salt"])
        #expect(used.isEmpty)
    }
}
