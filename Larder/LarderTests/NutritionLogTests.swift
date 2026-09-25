//
//  NutritionLogTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation
import Testing
@testable import Larder

@MainActor
struct NutritionLogTests {
    private func summary(_ id: String, eaten: Int = 1) throws -> MealSummary {
        let recipe = try #require(RecipeStore.recipe(withID: id))
        return MealSummary(recipe: recipe, orderOutPrice: 14, servingsEaten: eaten)
    }

    @Test func aMealStoresWhatWasEaten() throws {
        let db = try TestDatabase()
        let meal = MealLog.record(try summary("egg-fried-rice"), in: db.context)
        #expect(abs((meal.calories ?? 0) - 518) < 5)
        #expect((meal.protein ?? 0) > 20)
        #expect(meal.servingsEaten == 1)
        #expect(meal.nutrition != nil)
    }

    @Test func eatingBothServingsDoublesIt() throws {
        let one = try summary("chicken-rice-skillet", eaten: 1).nutritionEaten
        let both = try summary("chicken-rice-skillet", eaten: 2).nutritionEaten
        #expect(abs(both.kcal - 2 * one.kcal) < 0.001)
        #expect(abs(both.protein - 2 * one.protein) < 0.001)
    }

    @Test func servingsEatenStaysWithinWhatTheRecipeMakes() throws {
        #expect(try summary("egg-fried-rice", eaten: 5).servingsEaten == 1)
        #expect(try summary("egg-fried-rice", eaten: 0).servingsEaten == 1)
        #expect(try summary("chicken-rice-skillet", eaten: 9).servingsEaten == 2)
    }

    @Test func costStillCountsTheWholeRecipe() throws {
        let one = try summary("chicken-rice-skillet", eaten: 1)
        #expect(one.totalCost == one.costPerServing * 2)
    }

    @Test func mealsLoggedBeforeNutritionHaveNone() {
        let old = CookedMeal(recipeID: "x", title: "x", emoji: "🍽️", servings: 1, cost: 1, saved: 1)
        #expect(old.nutrition == nil)
    }
}

@MainActor
struct NutritionInsightsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Friday 25 September 2026, early afternoon.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 14))! }

    private func meal(daysAgo: Int, hour: Int = 12, kcal: Double? = 500, protein: Double = 30) -> CookedMeal {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        let at = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        let nutrition = kcal.map { Macros(kcal: $0, protein: protein, carbs: 50, fat: 15) }
        return CookedMeal(recipeID: "r", title: "r", emoji: "🍽️", cookedAt: at, servings: 1, cost: 1, saved: 1,
                          nutrition: nutrition, servingsEaten: 1)
    }

    private func insights(_ meals: [CookedMeal]) -> NutritionInsights {
        NutritionInsights.compute(from: meals, now: now, calendar: calendar)
    }

    @Test func todayAddsUpTheMealsCookedToday() {
        let result = insights([meal(daysAgo: 0, hour: 8, kcal: 400), meal(daysAgo: 0, hour: 19, kcal: 600)])
        #expect(result.mealsToday == 2)
        #expect(result.today.kcal == 1_000)
        #expect(result.today.protein == 60)
    }

    @Test func theWeekIsSevenDaysOldestFirstEndingToday() {
        let result = insights([])
        #expect(result.days.count == 7)
        #expect(result.days.last?.start == calendar.startOfDay(for: now))
        #expect(result.days.first?.start == calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)))
    }

    @Test func nothingCookedMeansNoAverage() {
        #expect(insights([]).dailyAverage == nil)
        #expect(insights([]).mealsToday == 0)
    }

    @Test func theAverageOnlyCountsDaysSomethingWasCooked() {
        let result = insights([meal(daysAgo: 0, kcal: 600), meal(daysAgo: 2, kcal: 400)])
        #expect(result.dailyAverage?.kcal == 500)
        #expect(result.mealsThisWeek == 2)
    }

    @Test func mealsWithoutNutritionAreLeftOut() {
        let result = insights([meal(daysAgo: 0, kcal: nil), meal(daysAgo: 1, kcal: 300)])
        #expect(result.mealsThisWeek == 1)
        #expect(result.mealsToday == 0)
    }

    @Test func mealsOlderThanAWeekDontCount() {
        let result = insights([meal(daysAgo: 7, kcal: 900), meal(daysAgo: 6, kcal: 300)])
        #expect(result.mealsThisWeek == 1)
        #expect(result.dailyAverage?.kcal == 300)
    }
}

struct UnitConversionTests {
    @Test func feetAndInchesRoundToTheNearestInch() {
        let height = UnitConversion.feetAndInches(fromCm: 175)
        #expect(height.feet == 5 && height.inches == 9)
        #expect(abs(UnitConversion.cm(feet: 5, inches: 9) - 175.26) < 0.01)
    }

    @Test func poundsAndKilogramsConvertBothWays() {
        #expect(abs(UnitConversion.pounds(kg: 70) - 154.3) < 0.1)
        #expect(abs(UnitConversion.kg(pounds: UnitConversion.pounds(kg: 70)) - 70) < 0.001)
    }
}
