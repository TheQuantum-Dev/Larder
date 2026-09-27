//
//  NutmegChatUpgradeTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/27/26.
//

import Foundation
import Testing
@testable import Larder

/// Today's meals, pantry changes from the chat, moods, surprises and online ideas.
struct NutmegChatUpgradeTests {
    private let brain = OfflineBrain(fallback: { _ in nil })
    private let stocked = ["egg", "rice", "frozen-veg", "soy-sauce", "bread", "cheese", "butter", "pasta", "tomato-sauce"]

    private func kitchen(_ ids: [String], online: [Recipe] = [],
                         status: KitchenSnapshot.OnlineAvailability = .unavailable) -> KitchenSnapshot {
        var snapshot = KitchenSnapshot()
        snapshot.pantry = ids.compactMap { IngredientCatalog.ingredient(withID: $0) }
            .map { KitchenSnapshot.Item(id: $0.id, name: $0.name, emoji: $0.emoji, amount: $0.id == "egg" ? "3" : nil,
                                        quantity: $0.id == "egg" ? 3 : nil, unit: $0.id == "egg" ? "items" : nil) }
        snapshot.matches = RecipePool.matches(bundled: RecipeStore.all, online: online, onlineOnly: false) {
            RecipeMatcher.matches(recipes: $0, pantry: Set(ids), maxMissing: .max)
        }
        snapshot.online = status
        return snapshot
    }

    private func onlineRecipe(needs ids: [String]) -> Recipe {
        Recipe(id: "sp-42", title: "Online omelette", emoji: "🍳", minutes: 10, servings: 1, equipment: [.pan],
               ingredients: ids.map { RecipeIngredient(id: $0, amount: $0, qty: 1, optional: nil, alt: nil) },
               steps: [RecipeStep(text: "Cook it.", timer: nil)], tip: "", healthy: false,
               source: RecipeSource(name: "Somewhere", url: nil, credit: nil))
    }

    // MARK: Understanding

    @Test func newQuestionsAreRecognised() {
        #expect(brain.intent(for: "What did I eat today?") == .eatenToday)
        #expect(brain.intent(for: "what have I had so far") == .eatenToday)
        #expect(brain.intent(for: "I'm hungry, what should I eat?") == .moodQuestion)
        #expect(brain.intent(for: "no idea what to cook") == .moodQuestion)
        #expect(brain.intent(for: "Surprise me") == .surprise)
        #expect(brain.intent(for: "Something sweet") == .craving(.sweet))
        #expect(brain.intent(for: "something warm and cozy") == .craving(.warm))
        #expect(brain.intent(for: "Something spicy") == .craving(.spicy))
        #expect(brain.intent(for: "Something new from online") == .onlineIdea)
        if case .pantryChange(let command) = brain.intent(for: "add 6 eggs") {
            #expect(command.lines.first?.item.id == "egg")
        } else {
            Issue.record("adding eggs should be a pantry change")
        }
        // The old ones still mean what they did.
        #expect(brain.intent(for: "What can I make tonight?") == .whatCanIMake)
        #expect(brain.intent(for: "what can I make with eggs") == .withIngredients(["egg"]))
        #expect(brain.intent(for: "I only have a microwave") == .noStove)
        #expect(brain.intent(for: "sweet potato ideas") == .withIngredients(["sweet-potato"]))
    }

    // MARK: Today's meals

    @Test func todaysMealsAreListedWithTheirNumbers() {
        var k = kitchen(stocked)
        let time = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date())!
        k.mealsTodayList = [.init(title: "Grilled cheese", time: time,
                                  macros: Macros(kcal: 420, protein: 15, carbs: 40, fat: 22))]
        k.mealsToday = 1
        k.today = Macros(kcal: 420, protein: 15, carbs: 40, fat: 22)
        k.targets = DailyTargets(kcal: 2000, protein: 100, carbs: 250, fat: 70, isPersonal: true)
        let text = brain.answer(.eatenToday, in: k).text
        #expect(text.contains("grilled cheese"))
        #expect(text.contains("420 kcal"))
        #expect(text.contains("40 g carbs"))
        #expect(text.contains("Left for today: about 1,580 kcal, 85 g protein, 210 g carbs and 48 g fat"))
        #expect(text.contains("only meals cooked here"))
    }

    @Test func withNumbersOffTodaysMealsHaveNone() {
        var k = kitchen(stocked)
        k.showsNutrition = false
        k.mealsTodayList = [.init(title: "Grilled cheese", time: Date(), macros: Macros(kcal: 420, protein: 15, carbs: 40, fat: 22))]
        let text = brain.answer(.eatenToday, in: k).text
        #expect(text.contains("grilled cheese"))
        #expect(!text.contains("kcal"))
    }

    @Test func nothingEatenYetOffersIdeas() {
        let reply = brain.answer(.eatenToday, in: kitchen(stocked))
        #expect(reply.text.contains("Nothing cooked"))
        #expect(!reply.quickReplies.isEmpty)
    }

    @Test func caloriesTodayNowSaysWhatMacrosAreLeft() {
        var k = kitchen(stocked)
        k.mealsToday = 1
        k.today = Macros(kcal: 500, protein: 20, carbs: 60, fat: 15)
        k.targets = DailyTargets(kcal: 2000, protein: 100, carbs: 250, fat: 70, isPersonal: true)
        let text = brain.answer(.caloriesToday, in: k).text
        #expect(text.contains("to go"))
        #expect(text.contains("80 g protein, 190 g carbs and 55 g fat"))
    }

    // MARK: Pantry changes

    @Test func aPantryChangeComesBackAsACardNotAChange() throws {
        let reply = brain.reply(to: "add 6 eggs and 2 cans of beans", in: kitchen(stocked))
        let command = try #require(reply.pantryChange)
        #expect(command.lines.map(\.item.id) == ["egg", "beans"])
        #expect(reply.recipeIDs.isEmpty)
    }

    @Test func takingOffSomethingThatIsNotThereSaysSo() {
        let reply = brain.reply(to: "I ran out of milk", in: kitchen(stocked))
        #expect(reply.pantryChange == nil)
        #expect(reply.text.contains("Milk isn't in your pantry"))
    }

    @Test func aProposalAddsToWhatWasAlreadyCounted() throws {
        let k = kitchen(stocked)
        let command = try #require(PantryCommand.parse("add 6 eggs and 2 cans of beans"))
        var proposal = PantryProposal(command, pantry: k.pantry)
        #expect(proposal.lines.map(\.label) == ["+6", "+2 cans"])
        // Eggs were counted at 3, so 6 more makes 9.
        #expect(proposal.update.amounts == ["egg": 9])
        #expect(proposal.update.add.map(\.id) == ["beans"])
        #expect(proposal.update.addAmounts == ["beans": 2])
        #expect(proposal.update.units["beans"] == .cans)
        proposal.step("beans", by: 1)
        #expect(proposal.update.addAmounts == ["beans": 3])
        #expect(proposal.confirmation == "Done! I've added eggs (6) and beans (3 cans).")
    }

    @Test func settingToNoneTakesItOff() throws {
        let k = kitchen(stocked)
        var proposal = PantryProposal(try #require(PantryCommand.parse("I only have 1 egg left")), pantry: k.pantry)
        #expect(proposal.lines.first?.label == "Now 1")
        proposal.step("egg", by: -1)
        #expect(proposal.update.remove == ["egg"])
        #expect(proposal.confirmation.contains("took eggs off"))
    }

    @Test func aStateOtherThanPendingCannotBeChanged() throws {
        let k = kitchen(stocked)
        var proposal = PantryProposal(try #require(PantryCommand.parse("add 6 eggs")), pantry: k.pantry)
        proposal.state = .applied
        proposal.step("egg", by: 1)
        #expect(proposal.lines.first?.quantity == 6)
    }

    // MARK: Moods and surprises

    @Test func aVagueAskGetsAQuestionBackWithChoices() {
        let reply = brain.reply(to: "what should I eat", in: kitchen(stocked))
        #expect(reply.text.contains("in the mood for"))
        #expect(reply.quickReplies.contains("Something quick"))
        #expect(reply.quickReplies.last == "Surprise me")
        #expect(!reply.quickReplies.contains("Something new from online"))
        // Every choice is understood when it's tapped.
        for choice in reply.quickReplies {
            #expect(brain.intent(for: choice) != .offTopic)
            #expect(brain.intent(for: choice) != .moodQuestion)
        }
    }

    @Test func surpriseMePicksOneRecipe() {
        let reply = brain.reply(to: "surprise me", in: kitchen(stocked))
        #expect(reply.recipeIDs.count == 1)
    }

    @Test func aCravingFindsFittingRecipes() {
        let reply = brain.reply(to: "something warm", in: kitchen(stocked))
        #expect(!reply.recipeIDs.isEmpty)
    }

    // MARK: Online ideas

    @Test func onlineIdeasComeFromTheOnlineRecipes() {
        let k = kitchen(stocked, online: [onlineRecipe(needs: ["egg"])], status: .ready)
        let reply = brain.reply(to: "something new from online", in: k)
        #expect(reply.recipeIDs == ["sp-42"])
        #expect(OfflineBrain.moods(for: k).contains("Something new from online"))
    }

    @Test func whenOnlineIsOffItSaysSoAndOffersLardersOwn() {
        let reply = brain.reply(to: "something from online", in: kitchen(stocked, status: .off))
        #expect(reply.text.contains("switched off"))
        #expect(!reply.recipeIDs.isEmpty)
        #expect(reply.recipeIDs.allSatisfy { !$0.hasPrefix("sp-") })
    }

    @Test func onlineRecipeIDsSurviveInAReply() {
        #expect(NutmegReply("x", recipeIDs: ["sp-42", "made-up"]).recipeIDs == ["sp-42"])
    }
}
