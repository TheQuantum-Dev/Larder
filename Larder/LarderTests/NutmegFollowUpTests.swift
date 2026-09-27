//
//  NutmegFollowUpTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/27/26.
//

import Foundation
import Testing
@testable import Larder

/// Nutmeg keeping track of the conversation: yes and no, "show me more",
/// "the first one", and the shopping list.
@MainActor
struct NutmegFollowUpTests {
    private let brain = OfflineBrain(fallback: { _ in nil })

    private func kitchen(_ ids: [String], amounts: [String: (Double, String)] = [:],
                         shopping: [KitchenSnapshot.ShoppingLine] = []) -> KitchenSnapshot {
        var snapshot = KitchenSnapshot()
        snapshot.pantry = ids.compactMap { IngredientCatalog.ingredient(withID: $0) }.map { item in
            let amount = amounts[item.id]
            return KitchenSnapshot.Item(id: item.id, name: item.name, emoji: item.emoji,
                                        amount: amount.flatMap { PantryAmount.text(quantity: $0.0, unit: $0.1) },
                                        quantity: amount?.0, unit: amount?.1)
        }
        snapshot.matches = RecipeMatcher.matches(pantry: Set(ids), maxMissing: .max)
        snapshot.shopping = shopping
        return snapshot
    }

    private let stocked = ["egg", "rice", "frozen-veg", "soy-sauce", "bread", "cheese", "butter", "pasta", "tomato-sauce"]

    /// A kitchen where every recipe still needs three things or more.
    private var farFromEverything: KitchenSnapshot {
        var k = kitchen(["ketchup"])
        k.matches = k.matches.filter { $0.missing.count >= 3 }
        return k
    }

    // MARK: The conversation from Joshua's screenshot

    @Test func nothingCloseStillShowsTheClosestAndOffersTheList() {
        let k = farFromEverything
        let reply = brain.reply(to: "What can I make tonight?", in: k)
        #expect(!reply.recipeIDs.isEmpty)
        #expect(reply.text.contains("The closest is"))
        #expect(!reply.text.contains("Nothing like that"))
        if case .addToList(let entries) = reply.offer {
            #expect(!entries.isEmpty)
        } else {
            Issue.record("it should offer to put what's needed on the list")
        }
    }

    @Test func yesAcceptsTheOfferAndAddsToTheList() async {
        let chat = ChatModel(engine: .offline)
        var added: [ShoppingEntry] = []
        chat.onAddToList = { added += $0 }
        let k = farFromEverything
        await chat.send("What can I make tonight?", kitchen: k)
        await chat.send("Yes", kitchen: k)
        #expect(!added.isEmpty)
        #expect(chat.messages.last?.text.contains("shopping list") == true)
    }

    @Test func tappingTheOfferChipCountsAsYes() async {
        let chat = ChatModel(engine: .offline)
        var added: [ShoppingEntry] = []
        chat.onAddToList = { added += $0 }
        let k = farFromEverything
        await chat.send("What can I make tonight?", kitchen: k)
        await chat.send("Yes, add it to my list", kitchen: k)
        #expect(!added.isEmpty)
    }

    @Test func noLeavesItAlone() async {
        let chat = ChatModel(engine: .offline)
        var added: [ShoppingEntry] = []
        chat.onAddToList = { added += $0 }
        let k = farFromEverything
        await chat.send("What can I make tonight?", kitchen: k)
        await chat.send("No thanks", kitchen: k)
        #expect(added.isEmpty)
        #expect(chat.messages.last?.text.contains("No problem") == true)
    }

    @Test func aYesOutOfTheBlueAsksWhatTheyFancy() async {
        let chat = ChatModel(engine: .offline)
        await chat.send("Yes", kitchen: kitchen(stocked))
        #expect(chat.messages.last?.quickReplies.isEmpty == false)
        #expect(chat.messages.last?.text.contains("food things") == false)
    }

    @Test func showMeMoreGivesTheNextFew() async {
        let chat = ChatModel(engine: .offline)
        let k = kitchen(stocked)
        await chat.send("What can I make?", kitchen: k)
        let first = chat.messages.last?.recipeIDs ?? []
        await chat.send("Show me more", kitchen: k)
        let next = chat.messages.last?.recipeIDs ?? []
        #expect(!next.isEmpty)
        #expect(Set(first).isDisjoint(with: next))
    }

    @Test func theFirstOneMeansTheFirstCard() async {
        let chat = ChatModel(engine: .offline)
        let k = kitchen(stocked)
        await chat.send("What can I make?", kitchen: k)
        let first = chat.messages.last?.recipeIDs.first
        await chat.send("What do I need for the first one?", kitchen: k)
        #expect(chat.messages.last?.recipeIDs == first.map { [$0] })
    }

    // MARK: The shopping list

    @Test func addingToTheShoppingListIsNotAddingToThePantry() {
        #expect(brain.intent(for: "add milk to my shopping list") == .addToShoppingList([ShoppingEntry(item: IngredientCatalog.resolve("milk")!)]))
        if case .addToShoppingList(let entries) = brain.intent(for: "I need to buy 6 eggs and 2 cans of beans") {
            #expect(entries.map(\.item.id) == ["egg", "beans"])
            #expect(entries.map(\.amount) == [Amount(6), Amount(2, .cans)])
        } else {
            Issue.record("buying things should go on the list")
        }
        // Still the pantry when the list isn't mentioned.
        if case .pantryChange = brain.intent(for: "add 6 eggs") {} else { Issue.record("that's the pantry") }
    }

    @Test func askingForTheListReadsItOut() {
        #expect(brain.intent(for: "What's on my shopping list?") == .shoppingList)
        let k = kitchen(stocked, shopping: [.init(name: "Milk", amount: "1 bottle", isBought: false),
                                            .init(name: "Eggs", amount: nil, isBought: true)])
        let text = brain.answer(.shoppingList, in: k).text
        #expect(text.contains("milk (1 bottle)"))
        #expect(text.contains("1 already in your basket"))
    }

    @Test func runningLowOffersToAddThemToTheList() {
        #expect(brain.intent(for: "what am I running low on?") == .runningLow)
        let k = kitchen(stocked, amounts: ["egg": (1, "items"), "rice": (500, "g")])
        let reply = brain.answer(.runningLow, in: k)
        #expect(reply.text.contains("eggs (1)"))
        #expect(!reply.text.contains("rice"))
        if case .addToList(let entries) = reply.offer {
            #expect(entries.map(\.item.id) == ["egg"])
        } else {
            Issue.record("it should offer to add them")
        }
    }

    @Test func offTopicGivesWaysBackIn() {
        let reply = brain.reply(to: "who won the football", in: kitchen(stocked))
        #expect(!reply.quickReplies.isEmpty)
        #expect(reply.offer == .ideas)
    }
}
