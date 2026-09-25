//
//  NutmegChatTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/24/26.
//

import Foundation
import Testing
@testable import Larder

struct NutmegReplyTests {
    @Test func unknownRecipesAreDroppedAndAtMostThreeKept() {
        let reply = NutmegReply("hi", recipeIDs: ["made-up", "egg-fried-rice", "egg-fried-rice", "grilled-cheese",
                                                  "banana-oat-pancakes", "loaded-ramen"])
        #expect(reply.recipeIDs == ["egg-fried-rice", "grilled-cheese", "banana-oat-pancakes"])
    }
}

struct OfflineBrainTests {
    /// No embedding fallback, so every answer comes from the rules.
    private let brain = OfflineBrain(fallback: { _ in nil })

    private func kitchen(_ ids: [String], mealCount: Int = 0, streak: CookingStreak.Status = .none,
                         budget: Int = 0, weekCost: Double = 0) -> KitchenSnapshot {
        var snapshot = KitchenSnapshot()
        snapshot.pantry = ids.compactMap { IngredientCatalog.ingredient(withID: $0) }
            .map { KitchenSnapshot.Item(id: $0.id, name: $0.name, emoji: $0.emoji, amount: nil) }
        snapshot.matches = RecipeMatcher.matches(pantry: Set(ids), maxMissing: .max)
        snapshot.mealCount = mealCount
        snapshot.totalSaved = Double(mealCount) * 12
        snapshot.streak = streak
        snapshot.weeklyBudget = budget
        snapshot.weekCost = weekCost
        return snapshot
    }

    private let stocked = ["egg", "rice", "frozen-veg", "soy-sauce", "bread", "cheese", "butter", "pasta", "tomato-sauce"]

    // MARK: Understanding

    @Test func recognisesTheEverydayQuestions() {
        #expect(brain.intent(for: "hi") == .greeting)
        #expect(brain.intent(for: "Thanks!") == .thanks)
        #expect(brain.intent(for: "What can I make tonight?") == .whatCanIMake)
        #expect(brain.intent(for: "something quick, I'm in a rush") == .quick)
        #expect(brain.intent(for: "I'm broke, what's cheap") == .cheap)
        #expect(brain.intent(for: "I only have a microwave") == .noStove)
        #expect(brain.intent(for: "something healthier please") == .healthier)
        #expect(brain.intent(for: "what's in my fridge?") == .pantryContents)
        #expect(brain.intent(for: "how much have I saved") == .savings)
        #expect(brain.intent(for: "how's my streak") == .streak)
        #expect(brain.intent(for: "how's my budget looking") == .budget)
    }

    @Test func picksOutIngredientsAndRecipesByName() {
        #expect(brain.intent(for: "what can I make with eggs") == .withIngredients(["egg"]))
        #expect(brain.intent(for: "what do I need for grilled cheese?") == .aboutRecipe("grilled-cheese"))
    }

    @Test func somethingUnrelatedIsOffTopic() {
        #expect(brain.intent(for: "who won the football last night") == .offTopic)
    }

    @Test func theFallbackIsUsedOnlyWhenNoRuleMatches() {
        let withFallback = OfflineBrain(fallback: { _ in .savings })
        #expect(withFallback.intent(for: "tell me something nice") == .savings)
        #expect(withFallback.intent(for: "what can I make") == .whatCanIMake)
    }

    // MARK: Answering

    @Test func readyRecipesComeBackAsCards() {
        let reply = brain.reply(to: "what can I make", in: kitchen(stocked))
        #expect(!reply.recipeIDs.isEmpty)
        #expect(reply.recipeIDs.count <= NutmegReply.maxRecipes)
        let snapshot = kitchen(stocked)
        #expect(reply.recipeIDs.allSatisfy { snapshot.match(for: $0)?.isReady == true })
    }

    @Test func anEmptyPantryGetsAKindAnswerAndNoRecipes() {
        let reply = brain.reply(to: "what can I make", in: kitchen([]))
        #expect(reply.recipeIDs.isEmpty)
        #expect(reply.text.contains("empty"))
    }

    @Test func quickAndCheapOnlyReturnWhatFits() {
        let snapshot = kitchen(stocked)
        let quick = brain.reply(to: "something quick", in: snapshot)
        #expect(quick.recipeIDs.allSatisfy { (RecipeStore.recipe(withID: $0)?.minutes ?? 99) <= RecipeFilter.quickMinutes })
        let noStove = brain.reply(to: "microwave only", in: snapshot)
        #expect(noStove.recipeIDs.allSatisfy { RecipeStore.recipe(withID: $0)?.needsNoStove == true })
    }

    @Test func ingredientAnswersOnlyUseThatIngredient() {
        let reply = brain.reply(to: "what can I do with eggs", in: kitchen(stocked))
        #expect(!reply.recipeIDs.isEmpty)
        for id in reply.recipeIDs {
            let recipe = RecipeStore.recipe(withID: id)!
            #expect(recipe.ingredients.contains { $0.id == "egg" || $0.alternatives.contains("egg") })
        }
    }

    @Test func askingAboutARecipeNamesWhatsMissing() {
        let reply = brain.reply(to: "what do I need for grilled cheese", in: kitchen(["bread"]))
        #expect(reply.recipeIDs == ["grilled-cheese"])
        #expect(reply.text.contains("cheese"))
        #expect(reply.text.contains("missing"))
    }

    @Test func statsAnswersUseTheRealNumbers() {
        let snapshot = kitchen(stocked, mealCount: 3, streak: .atRisk(days: 4), budget: 50, weekCost: 12)
        #expect(brain.reply(to: "how much have I saved", in: snapshot).text.contains("$36.00"))
        #expect(brain.reply(to: "my streak?", in: snapshot).text.contains("4-day"))
        #expect(brain.reply(to: "how's my budget", in: snapshot).text.contains("$38.00 left"))
    }

    @Test func offTopicGetsARedirectNotRecipes() {
        let reply = brain.reply(to: "what's the capital of France", in: kitchen(stocked))
        #expect(reply.recipeIDs.isEmpty)
        #expect(reply.text.contains("food"))
    }

    @Test func nothingEverScoldsAboutMoneyOrAnEmptyFridge() {
        let snapshots = [kitchen([]), kitchen(stocked, budget: 10, weekCost: 40)]
        let questions = ["what can I make", "how's my budget", "what do I have", "my streak"]
        for snapshot in snapshots {
            for question in questions {
                let text = brain.reply(to: question, in: snapshot).text.lowercased()
                #expect(!text.contains("should have"))
                #expect(!text.contains("too much"))
                #expect(!text.contains("failed"))
            }
        }
    }

    @Test func listsReadNaturally() {
        #expect(OfflineBrain.list(["eggs"]) == "eggs")
        #expect(OfflineBrain.list(["eggs", "rice"]) == "eggs and rice")
        #expect(OfflineBrain.list(["eggs", "rice", "cheese"]) == "eggs, rice and cheese")
    }
}

struct ModelPromptTests {
    private func kitchen(_ ids: [String]) -> KitchenSnapshot {
        var snapshot = KitchenSnapshot()
        snapshot.pantry = ids.compactMap { IngredientCatalog.ingredient(withID: $0) }
            .map { KitchenSnapshot.Item(id: $0.id, name: $0.name, emoji: $0.emoji, amount: $0.id == "egg" ? "6" : nil) }
        snapshot.matches = RecipeMatcher.matches(pantry: Set(ids), maxMissing: .max)
        snapshot.streak = .atRisk(days: 3)
        return snapshot
    }

    private func prompt(_ message: String, _ snapshot: KitchenSnapshot,
                        history: [(asked: String, answered: String)] = []) -> String {
        let brain = OfflineBrain(fallback: { _ in nil })
        let intent = brain.intent(for: message)
        return ModelBrain.prompt(for: message, kitchen: snapshot, intent: intent,
                                 candidates: brain.candidates(for: intent, in: snapshot), history: history)
    }

    @Test func thePromptCarriesThePantryRecipesStatsAndTheQuestionLast() {
        let text = prompt("something warm?", kitchen(["egg", "rice"]))
        let lines = text.split(separator: "\n").map(String.init)
        #expect(lines.first == "Pantry: Eggs (6), Rice.")
        #expect(lines.last == "Their message: something warm?")
        // Numbers stay out of the model's hands entirely.
        #expect(!text.contains("streak"))
        #expect(!text.contains("saved"))
        let recipeLines = lines.filter { $0.hasPrefix("- ") }
        #expect(recipeLines.count == ModelBrain.recipesInSummary)
        let titles = recipeLines.map { String($0.dropFirst(2).split(separator: ":").first!) }
        #expect(ModelBrain.recipeIDs(forTitles: titles).count == titles.count)
    }

    @Test func recipeLinesReadLikeASentenceWithNoIDs() {
        let match = RecipeMatcher.matches(recipes: [RecipeStore.recipe(withID: "grilled-cheese")!],
                                          pantry: ["bread"], maxMissing: .max).first!
        let line = ModelBrain.recipeLine(match)
        #expect(line.hasPrefix("- Grilled cheese: 10 min, about $"))
        #expect(line.contains("needs cheese and butter"))
        #expect(!line.contains("grilled-cheese"))
    }

    @Test func aCheaperFollowUpPutsTheCheapestRecipesFirst() {
        let text = prompt("and something cheaper?", kitchen(["egg", "rice", "bread", "cheese", "pasta", "tomato-sauce"]))
        let titles = text.split(separator: "\n").filter { $0.hasPrefix("- ") }
            .map { String($0.dropFirst(2).split(separator: ":").first!) }
        let costs = ModelBrain.recipeIDs(forTitles: titles).compactMap { RecipeStore.recipe(withID: $0)?.costPerServing }
        #expect(costs == costs.sorted())
    }

    @Test func theFollowUpSaysWhatTheyWantInPlainWords() {
        #expect(prompt("and something cheaper?", kitchen(["egg"])).contains("They want something cheap"))
        #expect(prompt("what can I make with rice", kitchen(["egg"])).contains("They want to use rice."))
        #expect(!prompt("what should I cook?", kitchen(["egg"])).contains("They want"))
    }

    @Test func titlesComeBackAsIDsAndMadeUpOnesAreDropped() {
        #expect(ModelBrain.recipeIDs(forTitles: ["Grilled cheese", "egg fried rice", "Unicorn stew", ""])
                == ["grilled-cheese", "egg-fried-rice"])
        #expect(ModelBrain.recipeIDs(forTitles: ["tomato pasta"]) == ["simple-tomato-pasta"])
    }

    @Test func anEmptyPantryIsSaidPlainly() {
        #expect(prompt("hi", kitchen([])).hasPrefix("Pantry: empty."))
    }

    @Test func earlierExchangesComeBeforeTheNewQuestion() {
        let text = prompt("and a cheaper one?", kitchen(["egg"]),
                          history: [(asked: "something quick", answered: "Try a veggie omelette.")])
        #expect(text.contains("Person: something quick\nNutmeg: Try a veggie omelette.\nTheir message: and a cheaper one?"))
    }

    @Test func questionsAboutNumbersAreAnsweredFromTheAppNotTheModel() {
        #expect(ModelBrain.answersFromFacts(.savings))
        #expect(ModelBrain.answersFromFacts(.streak))
        #expect(ModelBrain.answersFromFacts(.budget))
        #expect(ModelBrain.answersFromFacts(.pantryContents))
        #expect(!ModelBrain.answersFromFacts(.whatCanIMake))
        #expect(!ModelBrain.answersFromFacts(.offTopic))
        #expect(!ModelBrain.answersFromFacts(.withIngredients(["egg"])))
    }

    @Test func theInstructionsForbidStepsAndInventedRecipes() {
        let rules = ModelBrain.instructions.lowercased()
        #expect(rules.contains("never write cooking steps"))
        #expect(rules.contains("never invent a recipe"))
    }
}

struct NutmegNutritionTests {
    private let brain = OfflineBrain(fallback: { _ in nil })

    private func kitchen(showsNutrition: Bool = true, mealsToday: Int = 0, today: Macros = .zero,
                         targets: DailyTargets? = DailyTargets(kcal: 2_250, protein: 170, carbs: 240, fat: 70, isPersonal: false),
                         pantry ids: [String] = ["egg", "bread", "cheese", "canned-tuna", "mayo", "chicken", "tortilla", "lettuce"]) -> KitchenSnapshot {
        var snapshot = KitchenSnapshot()
        snapshot.pantry = ids.compactMap { IngredientCatalog.ingredient(withID: $0) }
            .map { KitchenSnapshot.Item(id: $0.id, name: $0.name, emoji: $0.emoji, amount: nil) }
        snapshot.matches = RecipeMatcher.matches(pantry: Set(ids), maxMissing: .max)
        snapshot.showsNutrition = showsNutrition
        snapshot.goal = .buildMuscle
        snapshot.targets = targets
        snapshot.mealsToday = mealsToday
        snapshot.today = today
        return snapshot
    }

    // MARK: Understanding

    @Test func recognisesNumberQuestions() {
        #expect(brain.intent(for: "how many calories have I had today") == .caloriesToday)
        #expect(brain.intent(for: "what's my calorie budget") == .caloriesToday)
        #expect(brain.intent(for: "how are my macros") == .caloriesToday)
        #expect(brain.intent(for: "how much protein today") == .proteinToday)
        #expect(brain.intent(for: "something high in protein") == .highProtein)
        #expect(brain.intent(for: "I want something low calorie") == .lowCalorie)
        #expect(brain.intent(for: "something filling") == .hearty)
    }

    @Test func questionsAboutAFoodOrARecipeStayAboutIt() {
        #expect(brain.intent(for: "how much protein is in eggs") == .ingredientNutrition("egg"))
        #expect(brain.intent(for: "calories in grilled cheese") == .aboutRecipe("grilled-cheese"))
    }

    // MARK: Answers

    @Test func todaysNumbersAreTheRealOnes() {
        let today = Macros(kcal: 1_234, protein: 86, carbs: 130, fat: 40)
        let reply = brain.reply(to: "how many calories today", in: kitchen(mealsToday: 2, today: today))
        #expect(reply.text.contains("1,230 kcal"))
        #expect(reply.text.contains("86 g protein"))
        #expect(reply.text.contains("2,250"))
        #expect(reply.text.contains("to go"))
        #expect(reply.text.contains("only meals cooked here"))
    }

    @Test func aDayWithNothingCookedIsSaidPlainly() {
        let reply = brain.reply(to: "how many calories today", in: kitchen())
        #expect(reply.text.contains("Nothing cooked in Larder yet today"))
        #expect(reply.text.contains("2,250"))
    }

    @Test func proteinPointsToHighProteinIdeasWhenThereIsRoomLeft() {
        let reply = brain.reply(to: "how much protein today", in: kitchen(mealsToday: 1, today: Macros(kcal: 500, protein: 30)))
        #expect(reply.text.contains("30 g protein"))
        #expect(!reply.recipeIDs.isEmpty)
        for id in reply.recipeIDs {
            #expect((RecipeStore.recipe(withID: id)?.nutrition.protein ?? 0) >= RecipeFilter.highProteinGrams)
        }
    }

    @Test func highProteinRecipesAreSortedByProtein() {
        let reply = brain.reply(to: "something high in protein", in: kitchen())
        let proteins = reply.recipeIDs.compactMap { RecipeStore.recipe(withID: $0)?.nutrition.protein }
        #expect(!proteins.isEmpty)
        #expect(proteins == proteins.sorted(by: >))
    }

    @Test func aFoodComesBackWithItsUSDANumbers() {
        let reply = brain.reply(to: "how much protein is in eggs", in: kitchen())
        #expect(reply.text.contains("143"))
        #expect(reply.text.contains("12.6"))
        #expect(reply.text.contains("USDA"))
    }

    @Test func aRecipeAnswerMentionsItsCalories() {
        let reply = brain.reply(to: "what do I need for tuna melt", in: kitchen())
        #expect(reply.text.contains("kcal"))
    }

    // MARK: Numbers off

    @Test func justCookKeepsEveryNumberOut() {
        let off = kitchen(showsNutrition: false, mealsToday: 1, today: Macros(kcal: 500, protein: 30))
        for question in ["how many calories today", "how much protein today", "something high in protein",
                         "how much protein is in eggs"] {
            let text = brain.reply(to: question, in: off).text
            let hasDigit = text.contains(where: \.isNumber)
            #expect(text.contains("turned numbers off"), "\(question)")
            #expect(hasDigit == false, "\(question) leaked a number")
        }
        #expect(!brain.reply(to: "what do I need for tuna melt", in: off).text.contains("kcal"))
    }

    // MARK: The model's side

    @Test func numbersAreAnsweredFromTheAppNotTheModel() {
        #expect(ModelBrain.answersFromFacts(.caloriesToday))
        #expect(ModelBrain.answersFromFacts(.proteinToday))
        #expect(ModelBrain.answersFromFacts(.ingredientNutrition("egg")))
        #expect(!ModelBrain.answersFromFacts(.highProtein))
    }

    @Test func thePromptCarriesTheGoalAndRecipeNumbersOnlyWhenNumbersAreOn() {
        let on = kitchen()
        let pickedOn = brain.candidates(for: .highProtein, in: on)
        let promptOn = ModelBrain.prompt(for: "high protein?", kitchen: on, intent: .highProtein, candidates: pickedOn, history: [])
        #expect(promptOn.contains("Their goal: build muscle"))
        #expect(promptOn.contains("kcal and"))

        let off = kitchen(showsNutrition: false)
        let promptOff = ModelBrain.prompt(for: "ideas?", kitchen: off, candidates: brain.candidates(for: .whatCanIMake, in: off), history: [])
        #expect(!promptOff.contains("Their goal"))
        #expect(!promptOff.contains("kcal"))
    }

    @Test func theModelIsToldNotToInventNumbers() {
        #expect(ModelBrain.instructions.contains("never work out or invent numbers"))
    }

    @Test func nutritionAnswersNeverScold() {
        let today = Macros(kcal: 3_000, protein: 200, carbs: 300, fat: 100)
        for snapshot in [kitchen(mealsToday: 3, today: today), kitchen()] {
            for question in ["how many calories today", "how much protein today", "calories left", "something low calorie"] {
                let text = brain.reply(to: question, in: snapshot).text.lowercased()
                #expect(!text.contains("should have"))
                #expect(!text.contains("too much"))
                #expect(!text.contains("failed"))
                #expect(!text.contains("over your"))
            }
        }
    }
}
