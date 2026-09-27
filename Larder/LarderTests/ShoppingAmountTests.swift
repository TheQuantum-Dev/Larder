//
//  ShoppingAmountTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/27/26.
//

import Foundation
import Testing
@testable import Larder

struct AmountMathTests {
    @Test func sameUnitsAddUp() {
        #expect(AmountMath.sum(Amount(3), Amount(6)) == Amount(9))
        #expect(AmountMath.sum(Amount(1, .cans), Amount(2, .cans)) == Amount(3, .cans))
    }

    @Test func weightsAndVolumesConvert() {
        #expect(AmountMath.sum(Amount(500, .grams), Amount(1, .kilograms)) == Amount(1.5, .kilograms))
        #expect(AmountMath.sum(Amount(250, .millilitres), Amount(250, .millilitres)) == Amount(500, .millilitres))
        #expect(AmountMath.sum(Amount(1, .litres), Amount(500, .millilitres)) == Amount(1.5, .litres))
    }

    @Test func someAndMissingAmounts() {
        #expect(AmountMath.sum(nil, Amount(2)) == Amount(2))
        #expect(AmountMath.sum(Amount(2), nil) == Amount(2))
        #expect(AmountMath.sum(nil, nil) == nil)
    }

    @Test func unitsThatDoNotAddUpTakeTheNewer() {
        #expect(AmountMath.sum(Amount(2, .cans), Amount(400, .grams)) == Amount(400, .grams))
    }

    @Test func weightsRoundUpToWhatAShopSells() {
        #expect(AmountMath.toBuy(grams: 70) == Amount(100, .grams))
        #expect(AmountMath.toBuy(grams: 227) == Amount(250, .grams))
        #expect(AmountMath.toBuy(grams: 10) == Amount(50, .grams))
        #expect(AmountMath.toBuy(grams: 1200) == Amount(1.5, .kilograms))
        #expect(AmountMath.toBuy(grams: 240, liquid: true) == Amount(250, .millilitres))
    }
}

struct ShoppingAmountTests {
    private func line(_ id: String, _ amount: String, qty: Double = 0, grams: Double? = nil,
                      optional: Bool? = nil) -> RecipeIngredient {
        RecipeIngredient(id: id, amount: amount, qty: qty, optional: optional, alt: nil, grams: grams)
    }

    @Test func countedThingsAreCounted() {
        #expect(ShoppingAmount.amount(for: line("egg", "2 eggs", qty: 2, grams: 100)) == Amount(2))
        #expect(ShoppingAmount.amount(for: line("onion", "½ onion", qty: 0.5, grams: 55)) == Amount(1))
        #expect(ShoppingAmount.amount(for: line("canned-tuna", "1 can tuna", qty: 1, grams: 140)) == Amount(1, .cans))
        #expect(ShoppingAmount.amount(for: line("beans", "1 can beans", qty: 2, grams: 240)) == Amount(1, .cans))
    }

    @Test func weighedThingsUseTheirWeight() {
        #expect(ShoppingAmount.amount(for: line("rice", "1 cup cooked rice", qty: 1, grams: 158)) == Amount(200, .grams))
        #expect(ShoppingAmount.amount(for: line("chicken", "2 chicken breasts", qty: 3, grams: 300)) == Amount(300, .grams))
        #expect(ShoppingAmount.amount(for: line("milk", "1 cup milk", qty: 1, grams: 244)) == Amount(250, .millilitres))
    }

    @Test func aSpoonfulIsNotWorthWritingDown() {
        #expect(ShoppingAmount.amount(for: line("soy-sauce", "1 tbsp soy sauce", qty: 1, grams: 16)) == nil)
        #expect(ShoppingAmount.amount(for: line("cheese", "cheese", qty: 1, grams: 30, optional: true)) == nil)
    }

    @Test func onlineLinesAreReadFromTheirText() {
        #expect(ShoppingAmount.amount(inText: "2 hoagie rolls, split") == Amount(2))
        #expect(ShoppingAmount.amount(inText: "8 ounces shrimp, 51-60 count, cooked") == Amount(250, .grams))
        #expect(ShoppingAmount.amount(inText: "1 lb ground beef") == Amount(500, .grams))
        #expect(ShoppingAmount.amount(inText: "2 large eggs") == Amount(2))
        #expect(ShoppingAmount.amount(inText: "1 can chickpeas") == Amount(1, .cans))
        #expect(ShoppingAmount.amount(inText: "1 cup baby spinach") == nil)
        #expect(ShoppingAmount.amount(inText: "8 tablespoons parmesan cheese") == nil)
        #expect(ShoppingAmount.amount(inText: "salt and pepper") == nil)
        #expect(ShoppingAmount.amount(inText: "1 1/2 lb chicken thighs") == Amount(700, .grams))
    }

    @Test func typedEntriesKeepTheirAmounts() {
        let beans = ShoppingEntry.parse("2 cans of beans")
        #expect(beans?.item.id == "beans")
        #expect(beans?.amount == Amount(2, .cans))
        #expect(ShoppingEntry.parse("6 eggs")?.amount == Amount(6))
        #expect(ShoppingEntry.parse("milk")?.amount == nil)
        #expect(ShoppingEntry.parse("milk")?.item.id == "milk")
        #expect(ShoppingEntry.parse("   ") == nil)
    }
}

@MainActor
struct ShoppingAmountListTests {
    private let egg = IngredientCatalog.resolve("egg")!
    private let rice = IngredientCatalog.resolve("rice")!
    private let spinach = IngredientCatalog.resolve("spinach")!

    @Test func addingAgainAddsTheAmountsTogether() throws {
        let db = try TestDatabase()
        ShoppingRepository.add([ShoppingEntry(item: egg, amount: Amount(6))], in: db.context)
        #expect(ShoppingRepository.add([ShoppingEntry(item: egg, amount: Amount(4))], in: db.context) == 0)
        let item = try #require(ShoppingRepository.all(in: db.context).first)
        #expect(item.amount == Amount(10))
    }

    @Test func buyingAddsToWhatThePantryHad() throws {
        let db = try TestDatabase()
        PantryRepository.add([egg, rice], in: db.context)
        PantryRepository.setAmount(3, unit: .items, for: "egg", in: db.context)
        ShoppingRepository.add([ShoppingEntry(item: egg, amount: Amount(6)),
                                ShoppingEntry(item: rice, amount: Amount(500, .grams)),
                                ShoppingEntry(item: spinach, amount: Amount(1, .bags))], in: db.context)
        for item in ShoppingRepository.all(in: db.context) { ShoppingRepository.toggleBought(item, in: db.context) }
        let moved = ShoppingRepository.moveBoughtToPantry(in: db.context)
        #expect(moved.count == 3)
        let pantry = Dictionary(uniqueKeysWithValues: PantryRepository.all(in: db.context).map { ($0.ingredientID, $0) })
        // 3 eggs plus the 6 bought.
        #expect(pantry["egg"]?.amount == Amount(9))
        // Rice had no amount ("some"), so now it's what was bought.
        #expect(pantry["rice"]?.amount == Amount(500, .grams))
        // Spinach is new, with its amount.
        #expect(pantry["spinach"]?.amount == Amount(1, .bags))
        #expect(moved.first { $0.name == "Eggs" }?.total == Amount(9))
        #expect(ShoppingRepository.all(in: db.context).isEmpty)
    }

    @Test func aRecipeAddsWhatItIsMissingWithAmounts() throws {
        let db = try TestDatabase()
        let match = try #require(RecipeMatcher.matches(pantry: ["rice", "soy-sauce", "frozen-veg"], maxMissing: .max)
            .first { $0.recipe.id == "egg-fried-rice" })
        ShoppingRepository.addMissing(from: match, in: db.context)
        let item = try #require(ShoppingRepository.all(in: db.context).first { $0.ingredientID == "egg" })
        #expect(item.amount == Amount(2))
    }
}

struct PantryLayoutTests {
    @Test func runningLowMeansNearlyOut() {
        #expect(PantryAmount.isRunningLow(Amount(1)))
        #expect(!PantryAmount.isRunningLow(Amount(2)))
        #expect(PantryAmount.isRunningLow(Amount(100, .grams)))
        #expect(!PantryAmount.isRunningLow(Amount(500, .grams)))
        #expect(PantryAmount.isRunningLow(Amount(0.1, .litres)))
        #expect(!PantryAmount.isRunningLow(nil))
    }

    @Test func theChipsOfferOnlyAislesWithSomethingInThem() {
        let options = PantryFilter.available(for: [.produce, .produce, .dairyAndEggs, nil])
        #expect(options.map(\.filter) == [.all, .category(.produce), .category(.dairyAndEggs), .other])
        #expect(options.map(\.count) == [4, 2, 1, 1])
        #expect(PantryFilter.other.includes(nil))
        #expect(!PantryFilter.category(.produce).includes(.grains))
        #expect(PantryFilter.all.includes(.grains))
    }

    @Test func theMoveMessageSaysWhatChanged() {
        let moved = [ShoppingRepository.Moved(name: "Eggs", total: Amount(9), wasInPantry: true),
                     ShoppingRepository.Moved(name: "Spinach", total: Amount(1, .bags), wasInPantry: false),
                     ShoppingRepository.Moved(name: "Yogurt", total: nil, wasInPantry: false)]
        #expect(ShoppingListView.summary(of: moved) == "Added to your pantry: eggs (now 9), spinach (1 bag) and yogurt.")
    }
}
