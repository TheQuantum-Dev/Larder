//
//  MealPlanTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation
import Testing
@testable import Larder

struct MealPlanTests {
    /// Los Angeles, because it has daylight saving time, which the meal-day
    /// rollover has to survive.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func midnight(_ day: Int, month: Int = 9) -> Date {
        calendar.startOfDay(for: at(day, 12, month: month))
    }

    private func next(_ now: Date, cooked: [Date] = []) -> NextMeal {
        MealPlan.next(now: now, cookedDates: cooked, calendar: calendar)
    }

    // MARK: - The clock decides the meal

    @Test func theClockPicksTheMeal() {
        let cases: [(hour: Int, minute: Int, slot: MealSlot)] = [
            (3, 59, .dinner), (4, 0, .breakfast), (10, 59, .breakfast), (11, 0, .lunch),
            (15, 59, .lunch), (16, 0, .dinner), (23, 59, .dinner),
        ]
        for c in cases {
            #expect(MealPlan.slot(at: at(25, c.hour, c.minute), calendar: calendar) == c.slot, "\(c.hour):\(c.minute)")
        }
    }

    @Test func theMealDayRollsOverAtFourInTheMorning() {
        #expect(MealPlan.mealDay(of: at(26, 3, 59), calendar: calendar) == midnight(25))
        #expect(MealPlan.mealDay(of: at(26, 4), calendar: calendar) == midnight(26))
        #expect(MealPlan.mealDay(of: at(25, 23, 59), calendar: calendar) == midnight(25))
    }

    // MARK: - Moving on after a meal

    @Test func withNothingCookedItIsWhateverMealTheClockSays() {
        #expect(next(at(25, 8)).slot == .breakfast)
        #expect(next(at(25, 8)).title == "Breakfast pick")
        #expect(next(at(25, 13)).slot == .lunch)
        #expect(next(at(25, 13)).title == "Lunch pick")
        #expect(next(at(25, 19)).slot == .dinner)
        #expect(next(at(25, 19)).title == "Tonight's pick")
    }

    @Test func aCookedBreakfastMovesTheMorningOnToLunch() {
        let meal = next(at(25, 9), cooked: [at(25, 8)])
        #expect(meal.slot == .lunch)
        #expect(!meal.isTomorrow)
    }

    @Test func aCookedLunchMovesTheAfternoonOnToDinner() {
        #expect(next(at(25, 13), cooked: [at(25, 12)]).slot == .dinner)
        #expect(next(at(25, 13), cooked: [at(25, 8), at(25, 12)]).slot == .dinner)
    }

    @Test func aMissedMealIsNotGoneBackTo() {
        // Nothing cooked this morning, and by the afternoon it's lunch, not breakfast.
        #expect(next(at(25, 14)).slot == .lunch)
    }

    @Test func afterDinnerItIsTomorrowsBreakfast() {
        let meal = next(at(25, 21), cooked: [at(25, 19)])
        #expect(meal.slot == .breakfast)
        #expect(meal.isTomorrow)
        #expect(meal.title == "Tomorrow's breakfast")
        #expect(meal.note != nil)
        #expect(meal.day == midnight(26))
        // Dinner isn't done, so there's no note.
        #expect(next(at(25, 21)).note == nil)
    }

    @Test func aDinnerCookedEarlyStillCountsAsDinner() {
        #expect(next(at(25, 16, 30), cooked: [at(25, 16, 5)]).isTomorrow)
    }

    @Test func aLunchCookedLateCountsAsLunch() {
        // 15:10 is still the lunch window, so dinner is what's next.
        #expect(next(at(25, 15, 20), cooked: [at(25, 15, 10)]).slot == .dinner)
    }

    @Test func pastMidnightTheBreakfastToComeIsNotTomorrows() {
        // Dinner was cooked at 8pm and it's now 1am: still the same meal-day, and
        // breakfast is only hours away.
        let meal = next(at(26, 1), cooked: [at(25, 20)])
        #expect(meal.slot == .breakfast)
        #expect(!meal.isTomorrow)
        #expect(meal.title == "Breakfast pick")
    }

    @Test func aMidnightSnackBelongsToTheNightBefore() {
        #expect(next(at(26, 1), cooked: [at(26, 0, 30)]).slot == .breakfast)
        // And it doesn't use up the 26th's own breakfast.
        #expect(next(at(26, 8), cooked: [at(26, 0, 30)]).slot == .breakfast)
        #expect(!next(at(26, 8), cooked: [at(26, 0, 30)]).isTomorrow)
    }

    @Test func yesterdaysMealsDoNotCountToday() {
        #expect(next(at(26, 8), cooked: [at(25, 8), at(25, 12), at(25, 19)]).slot == .breakfast)
    }

    @Test func mealsLeftCountsDownThroughTheDay() {
        #expect(MealSlot.breakfast.mealsLeft == 3)
        #expect(MealSlot.lunch.mealsLeft == 2)
        #expect(MealSlot.dinner.mealsLeft == 1)
        #expect(MealSlot.breakfast.following == .lunch)
        #expect(MealSlot.dinner.following == nil)
    }

    // MARK: - When to look again

    @Test func theSuggestionCanNextChangeAtTheNextMealBoundary() {
        #expect(MealPlan.nextBoundary(after: at(25, 8), calendar: calendar) == at(25, 11))
        #expect(MealPlan.nextBoundary(after: at(25, 11), calendar: calendar) == at(25, 16))
        #expect(MealPlan.nextBoundary(after: at(25, 16), calendar: calendar) == at(26, 4))
        #expect(MealPlan.nextBoundary(after: at(25, 23, 30), calendar: calendar) == at(26, 4))
        #expect(MealPlan.nextBoundary(after: at(26, 2), calendar: calendar) == at(26, 4))
    }

    @Test func boundariesSurviveTheClocksChanging() {
        // Spring forward: 2am on March 8th 2026 doesn't exist in Los Angeles.
        #expect(MealPlan.nextBoundary(after: at(8, 0, 30, month: 3), calendar: calendar) == at(8, 4, month: 3))
        #expect(MealPlan.slot(at: at(8, 4, 30, month: 3), calendar: calendar) == .breakfast)
        #expect(MealPlan.mealDay(of: at(8, 4, 30, month: 3), calendar: calendar) == midnight(8, month: 3))
        #expect(MealPlan.mealDay(of: at(8, 3, 30, month: 3), calendar: calendar) == midnight(7, month: 3))
        // Fall back: 1am happens twice on November 1st 2026.
        #expect(MealPlan.mealDay(of: at(1, 3, 30, month: 11), calendar: calendar) == midnight(31, month: 10))
        #expect(MealPlan.nextBoundary(after: at(1, 3, month: 11), calendar: calendar) == at(1, 4, month: 11))
    }

    // MARK: - What's already been eaten

    @Test func cookedTodayMeansThisMealDay() {
        let cooked = [(id: "a", date: at(25, 8)), (id: "b", date: at(24, 20)), (id: "c", date: at(26, 0, 30))]
        #expect(MealPlan.cookedIDs(cooked, onMealDayOf: at(25, 18), calendar: calendar) == ["a", "c"])
        #expect(MealPlan.cookedIDs(cooked, onMealDayOf: at(26, 9), calendar: calendar).isEmpty)
    }

    @Test func eatenAddsUpJustThatMealDay() {
        let meals: [(date: Date, macros: Macros)] = [
            (at(25, 8), Macros(kcal: 300, protein: 10, carbs: 40, fat: 8)),
            (at(25, 12), Macros(kcal: 500, protein: 30, carbs: 50, fat: 15)),
            (at(24, 19), Macros(kcal: 900, protein: 50, carbs: 90, fat: 30)),
        ]
        let total = MealPlan.eaten(meals, onMealDay: midnight(25), calendar: calendar)
        #expect(total == Macros(kcal: 800, protein: 40, carbs: 90, fat: 23))
    }

    // MARK: - Aiming at what's left of the day

    private let targets = DailyTargets(kcal: 2_100, protein: 150, carbs: 240, fat: 70, isPersonal: true)
    private var base: GoalContext { GoalContext(goal: .buildMuscle, perMeal: targets.perMeal) }

    private func close(_ a: Macros, _ b: Macros) -> Bool {
        abs(a.kcal - b.kcal) < 0.01 && abs(a.protein - b.protein) < 0.01
            && abs(a.carbs - b.carbs) < 0.01 && abs(a.fat - b.fat) < 0.01
    }

    @Test func withoutAGoalThereIsNothingToAdjust() {
        #expect(MealPlan.goalContext(base: nil, targets: targets, eaten: .zero, mealsLeft: 2) == nil)
        #expect(MealPlan.goalContext(base: base, targets: nil, eaten: .zero, mealsLeft: 2) == base)
    }

    @Test func aFreshDayKeepsTheUsualThird() throws {
        let context = try #require(MealPlan.goalContext(base: base, targets: targets, eaten: .zero, mealsLeft: 3))
        #expect(context.goal == .buildMuscle)
        #expect(close(context.perMeal, base.perMeal))
    }

    @Test func aBigMealLightensTheOnesThatFollow() throws {
        // 1,000 kcal by lunchtime leaves 1,100 for two meals: 550 each, under the usual 700.
        let eaten = Macros(kcal: 1_000, protein: 60, carbs: 100, fat: 40)
        let context = try #require(MealPlan.goalContext(base: base, targets: targets, eaten: eaten, mealsLeft: 2))
        #expect(abs(context.perMeal.kcal - 550) < 0.01)
        #expect(context.perMeal.kcal < base.perMeal.kcal)
    }

    @Test func aLightDayRaisesTheProteinAimForDinner() throws {
        // Only 20 g of protein so far: 130 g left for two meals is 65 g each, above the usual 50.
        let eaten = Macros(kcal: 400, protein: 20, carbs: 50, fat: 10)
        let context = try #require(MealPlan.goalContext(base: base, targets: targets, eaten: eaten, mealsLeft: 2))
        #expect(abs(context.perMeal.protein - 65) < 0.01)
    }

    @Test func theAimStaysInABandAroundTheUsualThird() throws {
        let everything = Macros(kcal: 3_000, protein: 200, carbs: 300, fat: 100)
        let over = try #require(MealPlan.goalContext(base: base, targets: targets, eaten: everything, mealsLeft: 1))
        #expect(abs(over.perMeal.kcal - base.perMeal.kcal * MealPlan.lowest) < 0.01)

        let untouched = try #require(MealPlan.goalContext(base: base, targets: targets, eaten: .zero, mealsLeft: 1))
        #expect(abs(untouched.perMeal.kcal - base.perMeal.kcal * MealPlan.highest) < 0.01)
    }
}

struct NextMealPickerTests {
    private func match(_ id: String, meals: [String]? = nil, missing: Int = 0) -> RecipeMatch {
        let recipe = Recipe(id: id, title: id, emoji: "🍽️", minutes: 10, servings: 1, equipment: [],
                            ingredients: [], steps: [RecipeStep(text: "Cook it.", timer: nil)],
                            tip: "Enjoy.", healthy: false, meals: meals)
        let lines = (0..<missing).map { RecipeIngredient(id: "missing-\($0)", amount: "x", qty: 1, optional: nil, alt: nil) }
        return RecipeMatch(recipe: recipe, missing: lines, required: 3)
    }

    private let day = Date(timeIntervalSince1970: 1_800_000_000)
    private var breakfast: NextMeal { NextMeal(slot: .breakfast, day: day, isTomorrow: false) }
    private var dinner: NextMeal { NextMeal(slot: .dinner, day: day, isTomorrow: false) }

    private func ids(_ matches: [RecipeMatch]) -> [String] { matches.map(\.id) }

    @Test func whatWasCookedTodayIsNotOfferedAgain() {
        let matches = [match("a"), match("b"), match("c")]
        let picks = NextMealPicker.candidates(from: matches, next: dinner, cookedToday: ["a"], taste: .none)
        #expect(ids(picks) == ["b", "c"])
    }

    @Test func aThumbsDownIsNotAutoPicked() {
        let matches = [match("a"), match("b")]
        let picks = NextMealPicker.candidates(from: matches, next: dinner, cookedToday: [],
                                              taste: RecipeTaste(disliked: ["a"]))
        #expect(ids(picks) == ["b"])
    }

    @Test func aRecipeThatSuitsTheMealComesFirstEvenIfLaterInTheRanking() {
        let matches = [match("stew", meals: ["dinner"]), match("toast", meals: ["breakfast", "lunch"])]
        #expect(ids(NextMealPicker.candidates(from: matches, next: breakfast, cookedToday: [], taste: .none)) == ["toast"])
        #expect(ids(NextMealPicker.candidates(from: matches, next: dinner, cookedToday: [], taste: .none)) == ["stew"])
    }

    @Test func oneIngredientAwayStillBeatsAReadyRecipeThatDoesNotSuit() {
        let matches = [match("stew", meals: ["dinner"]), match("toast", meals: ["breakfast"], missing: 1)]
        #expect(ids(NextMealPicker.candidates(from: matches, next: breakfast, cookedToday: [], taste: .none)) == ["toast"])
    }

    @Test func twoAwayDoesNotBeatAReadyRecipeThatDoesNotSuit() {
        let matches = [match("stew", meals: ["dinner"]), match("toast", meals: ["breakfast"], missing: 2)]
        let picks = NextMealPicker.candidates(from: matches, next: breakfast, cookedToday: [], taste: .none)
        #expect(ids(picks) == ["stew", "toast"])
    }

    @Test func recipesWithoutTagsSuitAnyMeal() {
        let matches = [match("anything")]
        #expect(ids(NextMealPicker.candidates(from: matches, next: breakfast, cookedToday: [], taste: .none)) == ["anything"])
    }

    @Test func theMatchersOrderIsKeptInsideAPool() {
        let matches = [match("b", meals: ["dinner"]), match("a", meals: ["dinner"]), match("c", meals: ["dinner"])]
        #expect(ids(NextMealPicker.candidates(from: matches, next: dinner, cookedToday: [], taste: .none)) == ["b", "a", "c"])
    }

    @Test func thereIsAlwaysSomethingWhileAnyRecipeMatches() {
        // Everything cooked today and thumbed down: still show something rather than an empty card.
        let matches = [match("a"), match("b")]
        let picks = NextMealPicker.candidates(from: matches, next: dinner, cookedToday: ["a", "b"],
                                              taste: RecipeTaste(disliked: ["a", "b"]))
        #expect(ids(picks) == ["a", "b"])
        // A thumbs down is given up before repeating something cooked today.
        let picks2 = NextMealPicker.candidates(from: matches, next: dinner, cookedToday: ["b"],
                                               taste: RecipeTaste(disliked: ["a"]))
        #expect(ids(picks2) == ["a"])
        #expect(NextMealPicker.candidates(from: [], next: dinner, cookedToday: [], taste: .none).isEmpty)
    }
}
