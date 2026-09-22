//
//  BudgetInsightsTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation
import Testing
@testable import Larder

@MainActor
struct BudgetInsightsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Wednesday 23 September 2026.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 12))!
    }

    private func meal(daysAgo: Int, cost: Double, saved: Double, servings: Int = 2, title: String = "Egg fried rice") -> CookedMeal {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        return CookedMeal(recipeID: title, title: title, emoji: "🍳", cookedAt: date,
                          servings: servings, cost: cost, saved: saved)
    }

    private func compute(_ meals: [CookedMeal], budget: Int = 0) -> BudgetInsights {
        BudgetInsights.compute(from: meals, budget: budget, now: now, calendar: calendar)
    }

    @Test func noMealsStillGivesFourZeroWeeks() {
        let insights = compute([])
        #expect(insights.weeks.count == 4)
        #expect(insights.weeks.allSatisfy { $0.cost == 0 && $0.meals == 0 })
        #expect(insights.averageCostPerServing == nil)
        #expect(insights.bestSave == nil)
        #expect(insights.mealCount == 0)
    }

    @Test func mealsAreGroupedIntoTheirOwnWeek() {
        // Monday the 21st is the start of this week; 5 days ago is in the week before.
        let insights = compute([meal(daysAgo: 0, cost: 3, saved: 10),
                                meal(daysAgo: 2, cost: 2, saved: 8),
                                meal(daysAgo: 5, cost: 4, saved: 9)])
        #expect(insights.weeks.last?.cost == 5)
        #expect(insights.weeks.last?.meals == 2)
        #expect(insights.weeks[2].cost == 4)
        #expect(insights.weekMeals == 2)
        #expect(insights.weekSaved == 18)
        #expect(insights.totalSaved == 27)
        #expect(insights.mealCount == 3)
    }

    @Test func weeksRunOldestToNewest() {
        let insights = compute([])
        let starts = insights.weeks.map(\.start)
        #expect(starts == starts.sorted())
    }

    @Test func mealsOlderThanTheWindowStillCountInTheTotals() {
        let insights = compute([meal(daysAgo: 60, cost: 6, saved: 20)])
        #expect(insights.weeks.allSatisfy { $0.meals == 0 })
        #expect(insights.mealCount == 1)
        #expect(insights.totalSaved == 20)
    }

    @Test func averageCostIsPerServingNotPerMeal() {
        let insights = compute([meal(daysAgo: 0, cost: 4, saved: 10, servings: 2),
                                meal(daysAgo: 1, cost: 6, saved: 10, servings: 4)])
        #expect(insights.averageCostPerServing == 10.0 / 6.0)
    }

    @Test func theBiggestSaveIsPickedAndZeroSavesAreIgnored() {
        let insights = compute([meal(daysAgo: 0, cost: 3, saved: 6, title: "Toast"),
                                meal(daysAgo: 1, cost: 3, saved: 12, title: "Curry")])
        #expect(insights.bestSave?.title == "Curry")
        #expect(compute([meal(daysAgo: 0, cost: 30, saved: 0)]).bestSave == nil)
    }

    @Test func standingComparesWeekCostWithBudget() {
        let meals = [meal(daysAgo: 0, cost: 12, saved: 5)]
        #expect(compute(meals, budget: 0).standing == .noBudget)
        #expect(compute(meals, budget: 0).standingText == nil)
        #expect(compute(meals, budget: 50).standing == .under(left: 38))
        #expect(compute(meals, budget: 50).standingText == "$38.00 left this week")
        #expect(compute(meals, budget: 10).standing == .over(by: 2))
        #expect(compute(meals, budget: 12).standing == .under(left: 0))
    }

    @Test func goingOverIsNeverPutAsAFailure() {
        let text = compute([meal(daysAgo: 0, cost: 20, saved: 5)], budget: 10).standingText ?? ""
        #expect(text.contains("$10.00 over"))
        #expect(text.contains("okay"))
    }

    @Test func budgetProgressStopsAtFull() {
        #expect(compute([meal(daysAgo: 0, cost: 25, saved: 1)], budget: 50).budgetProgress == 0.5)
        #expect(compute([meal(daysAgo: 0, cost: 90, saved: 1)], budget: 50).budgetProgress == 1)
        #expect(compute([], budget: 0).budgetProgress == 0)
    }

    @Test func cheapestReadyKeepsOnlyReadyRecipesCheapestFirst() {
        let recipes = RecipeStore.all
        let everything = Set(recipes.flatMap { $0.ingredients.map(\.id) })
        let matches = RecipeMatcher.matches(pantry: everything)
        let picks = BudgetInsights.cheapestReady(from: matches, limit: 3)
        #expect(picks.count == 3)
        #expect(picks.allSatisfy { $0.isReady })
        let costs = picks.map { $0.recipe.costPerServing }
        #expect(costs == costs.sorted())
        #expect(BudgetInsights.cheapestReady(from: RecipeMatcher.matches(pantry: [])).isEmpty)
    }
}
