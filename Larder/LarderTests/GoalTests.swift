//
//  GoalTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation
import Testing
@testable import Larder

struct FitnessGoalTests {
    @Test func onlyJustCookHidesTheNumbers() {
        for goal in FitnessGoal.allCases {
            #expect(goal.showsNutrition == (goal != .justCook))
            #expect(goal.detail != nil, "\(goal) needs a line under its name")
            #expect((goal.promise == nil) == (goal == .justCook))
        }
    }

    @Test func pickingOneReplacesTheOther() {
        var selection = MultiSelection<FitnessGoal>(single: true)
        #expect(selection.isEmpty)
        selection.toggle(.loseWeight)
        selection.toggle(.buildMuscle)
        #expect(selection.items == [.buildMuscle])
        selection.toggle(.buildMuscle)
        #expect(selection.items == [.buildMuscle], "tapping the pick again keeps it")
    }
}

struct NutritionTargetsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 12))! }

    private func stats(age: Int, sex: BiologicalSex?, cm: Double, kg: Double, _ activity: ActivityLevel) -> BodyStats {
        BodyStats(birthYear: 2026 - age, sex: sex, heightCm: cm, weightKg: kg, activity: activity)
    }

    private func targets(_ goal: FitnessGoal, _ stats: BodyStats) -> DailyTargets? {
        NutritionTargets.targets(for: goal, stats: stats, now: now, calendar: calendar)
    }

    @Test func aKnownPersonComesOutRight() throws {
        // 70 kg, 175 cm, 20, male, moderately active: 1,699 at rest, about 2,633 a day.
        let person = stats(age: 20, sex: .male, cm: 175, kg: 70, .moderate)
        let maintain = try #require(targets(.stayFit, person))
        #expect(maintain.kcal == 2_650)
        #expect(maintain.protein == 100)
        #expect(maintain.fat == 80)
        #expect((380...385).contains(maintain.carbs))
        #expect(maintain.isPersonal)

        let bulk = try #require(targets(.buildMuscle, person))
        #expect(bulk.kcal == maintain.kcal + 250)
        #expect(bulk.protein == 140, "2 g per kilo")
    }

    @Test func goalsMoveTheCaloriesInTheRightDirection() throws {
        let person = stats(age: 20, sex: .male, cm: 175, kg: 70, .moderate)
        let fit = try #require(targets(.stayFit, person)).kcal
        #expect(try #require(targets(.loseWeight, person)).kcal < fit)
        #expect(try #require(targets(.gainWeight, person)).kcal > fit)
        #expect(try #require(targets(.buildMuscle, person)).kcal > fit)
    }

    @Test func losingWeightNeverGoesBelowASafeFloor() throws {
        let small = stats(age: 22, sex: .female, cm: 150, kg: 45, .sedentary)
        #expect(try #require(targets(.loseWeight, small)).kcal == 1_200)
    }

    @Test func noStatsMeansASensibleBaseline() throws {
        let none = BodyStats()
        let fit = try #require(targets(.stayFit, none))
        #expect(fit.kcal == 2_000 && !fit.isPersonal)
        #expect(try #require(targets(.loseWeight, none)).kcal == 1_700)
        #expect(try #require(targets(.gainWeight, none)).kcal == 2_400)
        #expect(try #require(targets(.buildMuscle, none)).kcal == 2_250)
    }

    @Test func justCookHasNoTargets() {
        #expect(targets(.justCook, BodyStats()) == nil)
    }

    @Test func nobodyUnderEighteenIsPutOnADeficit() throws {
        let teen = stats(age: 16, sex: .female, cm: 165, kg: 60, .light)
        #expect(try #require(targets(.loseWeight, teen)) == (try #require(targets(.stayFit, teen))))
    }

    @Test func numbersThatCantBeARealPersonAreIgnored() throws {
        let typo = stats(age: 20, sex: .male, cm: 5, kg: 70, .light)
        #expect(try #require(targets(.stayFit, typo)).isPersonal == false)
    }

    @Test func aMealIsAThirdOfTheDay() throws {
        let day = try #require(targets(.stayFit, BodyStats()))
        #expect(abs(day.perMeal.kcal - 2_000.0 / 3) < 0.001)
    }

    @Test func ageComesFromTheBirthYear() {
        #expect(BodyStats(birthYear: 2006).age(now: now, calendar: calendar) == 20)
        #expect(BodyStats(birthYear: 1900).age(now: now, calendar: calendar) == nil)
        #expect(BodyStats().age(now: now, calendar: calendar) == nil)
    }
}

struct GoalFitTests {
    private func context(_ goal: FitnessGoal, perMealKcal: Double = 700) -> GoalContext {
        GoalContext(goal: goal, perMeal: Macros(kcal: perMealKcal))
    }

    @Test func muscleWantsProtein() {
        let ctx = context(.buildMuscle)
        let chicken = Macros(kcal: 600, protein: 40, carbs: 40, fat: 15)
        let toast = Macros(kcal: 600, protein: 10, carbs: 80, fat: 20)
        #expect(GoalFit.penalty(for: chicken, in: ctx) == 0)
        #expect(GoalFit.penalty(for: toast, in: ctx) > GoalFit.penalty(for: chicken, in: ctx))
    }

    @Test func weightLossPenalisesBigMealsAndLowProtein() {
        let ctx = context(.loseWeight, perMealKcal: 550)
        let light = Macros(kcal: 400, protein: 30)
        let heavy = Macros(kcal: 800, protein: 30)
        #expect(GoalFit.penalty(for: heavy, in: ctx) > GoalFit.penalty(for: light, in: ctx))
    }

    @Test func gainingPenalisesSmallMeals() {
        let ctx = context(.gainWeight, perMealKcal: 800)
        #expect(GoalFit.penalty(for: Macros(kcal: 300), in: ctx) > GoalFit.penalty(for: Macros(kcal: 850), in: ctx))
        #expect(GoalFit.penalty(for: Macros(kcal: 850), in: ctx) == 0)
    }

    @Test func badgesOnlyAppearWhenTheRecipeClearlyFits() {
        #expect(GoalFit.badge(for: Macros(kcal: 500, protein: 34), in: context(.buildMuscle)) == "💪 High protein · 34 g")
        #expect(GoalFit.badge(for: Macros(kcal: 500, protein: 12), in: context(.buildMuscle)) == nil)
        #expect(GoalFit.badge(for: Macros(kcal: 380, protein: 20), in: context(.loseWeight, perMealKcal: 570)) == "🍃 Light · 380 kcal")
        #expect(GoalFit.badge(for: Macros(kcal: 780, protein: 30), in: context(.gainWeight)) == "🍚 Hearty · 780 kcal")
        #expect(GoalFit.badge(for: Macros(kcal: 520, protein: 24), in: context(.stayFit)) == "⚖️ Balanced · 24 g protein")
        #expect(GoalFit.badge(for: Macros(kcal: 900, protein: 60), in: context(.justCook)) == nil)
    }
}

@MainActor
struct GoalRankingTests {
    private func recipe(_ id: String, _ line: RecipeIngredient) -> Recipe {
        Recipe(id: id, title: id, emoji: "🍽️", minutes: 10, servings: 1, equipment: [], ingredients: [line],
               steps: [RecipeStep(text: "Cook it.", timer: nil)], tip: "Enjoy.", healthy: false)
    }

    private var recipes: [Recipe] {
        [
            recipe("toast", RecipeIngredient(id: "bread", amount: "bread", qty: 2, optional: nil, alt: nil, grams: 100)),
            recipe("chicken", RecipeIngredient(id: "chicken", amount: "chicken", qty: 2, optional: nil, alt: nil, grams: 200)),
        ]
    }

    private let pantry: Set<String> = ["bread", "chicken"]

    @Test func withoutAGoalTheCheaperMealWinsTheTie() {
        let order = RecipeMatcher.matches(recipes: recipes, pantry: pantry).map(\.recipe.id)
        #expect(order == ["toast", "chicken"])
    }

    @Test func aMuscleGoalPutsTheProteinFirst() {
        let goal = GoalContext(goal: .buildMuscle, perMeal: Macros(kcal: 750))
        let order = RecipeMatcher.matches(recipes: recipes, pantry: pantry, goal: goal).map(\.recipe.id)
        #expect(order == ["chicken", "toast"])
    }

    @Test func aGoalNeverOutranksBeingReadyToCook() {
        let goal = GoalContext(goal: .buildMuscle, perMeal: Macros(kcal: 750))
        let order = RecipeMatcher.matches(recipes: recipes, pantry: ["bread"], goal: goal).map(\.recipe.id)
        #expect(order.first == "toast", "the recipe you can cook now still comes first")
    }

    @Test func theGoalBadgeComesFirstAndTheCapHolds() throws {
        let tuna = try #require(RecipeStore.recipe(withID: "tuna-melt"))
        let match = RecipeMatch(recipe: tuna, missing: [], required: 4)
        let goal = GoalContext(goal: .buildMuscle, perMeal: Macros(kcal: 750))
        let badges = RecipeBadges.reasons(for: match, priorities: [.saveMoney, .fast, .eatHealthier, .cutWaste],
                                          cooking: [], goal: goal)
        #expect(badges.first?.hasPrefix("💪 High protein") == true)
        #expect(badges.count <= 2)
    }
}

@MainActor
struct NutritionFilterTests {
    private func match(_ id: String) throws -> RecipeMatch {
        let recipe = try #require(RecipeStore.recipe(withID: id))
        return RecipeMatch(recipe: recipe, missing: [], required: 1)
    }

    @Test func highProteinKeepsTheProteinRichOnes() throws {
        #expect(RecipeFilter.highProtein.includes(try match("tuna-melt")))
        #expect(!RecipeFilter.highProtein.includes(try match("grilled-cheese")))
    }

    @Test func lighterAndHeartySplitOnCalories() throws {
        #expect(RecipeFilter.lighter.includes(try match("microwave-oatmeal")))
        #expect(!RecipeFilter.lighter.includes(try match("stovetop-mac-cheese")))
        #expect(RecipeFilter.hearty.includes(try match("stovetop-mac-cheese")))
        #expect(!RecipeFilter.hearty.includes(try match("microwave-oatmeal")))
    }

    @Test func numberChipsAreHiddenWhenNumbersAreOff() {
        let off = RecipeFilter.available(showsNutrition: false)
        #expect(!off.contains(.highProtein) && !off.contains(.lighter) && !off.contains(.hearty))
        #expect(off.contains(.quick))
        #expect(RecipeFilter.available(showsNutrition: true).contains(.highProtein))
    }
}

struct ProfileGoalTests {
    @Test func aProfileSavedBeforeGoalsStillLoads() throws {
        let old = #"{"diets":["vegan"],"cooking":["improvise"],"priorities":["saveMoney"]}"#
        let profile = try JSONDecoder().decode(Profile.self, from: Data(old.utf8))
        #expect(profile.dietSet == [.vegan])
        #expect(profile.fitnessGoal == nil)
        #expect(profile.showsNutrition, "people who haven't picked yet still see recipe calories")
    }

    @Test func aGoalAndBodyStatsRoundTrip() throws {
        var profile = Profile(diets: [.vegan], cooking: [], priorities: [], goal: .loseWeight)
        profile.bodyStats = BodyStats(birthYear: 2005, sex: .female, heightCm: 165, weightKg: 60, activity: .moderate)
        let data = try JSONEncoder().encode(profile)
        let back = try JSONDecoder().decode(Profile.self, from: data)
        #expect(back == profile)
        #expect(back.fitnessGoal == .loseWeight)
        #expect(back.bodyStats.sex == .female && back.bodyStats.activity == .moderate)
        #expect(back.dailyTargets != nil && back.goalContext?.goal == .loseWeight)
    }

    @Test func justCookMeansNoNumbersAnywhere() {
        let profile = Profile(diets: [], cooking: [], priorities: [], goal: .justCook)
        #expect(!profile.showsNutrition)
        #expect(profile.dailyTargets == nil)
        #expect(profile.goalContext == nil)
    }

    @Test func updatingTheQuizAnswersLeavesBodyStatsAlone() {
        var profile = Profile(diets: [], cooking: [], priorities: [], goal: .stayFit)
        profile.bodyStats = BodyStats(birthYear: 2004, sex: .male, heightCm: 180, weightKg: 75, activity: .light)
        profile.update(diets: [.vegetarian], cooking: [.improvise], priorities: [.fast], goal: .buildMuscle)
        #expect(profile.dietSet == [.vegetarian])
        #expect(profile.fitnessGoal == .buildMuscle)
        #expect(profile.weightKg == 75 && profile.birthYear == 2004)
    }
}
