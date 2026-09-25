//
//  ShoppingListTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation
import Testing
@testable import Larder

@MainActor
struct ShoppingListTests {
    private let egg = IngredientCatalog.resolve("egg")!
    private let rice = IngredientCatalog.resolve("rice")!
    private let milk = IngredientCatalog.resolve("milk")!

    @Test func addingSkipsWhatIsAlreadyOnTheList() throws {
        let db = try TestDatabase()
        #expect(ShoppingRepository.add([egg, rice], in: db.context) == 2)
        #expect(ShoppingRepository.add([egg, milk], in: db.context) == 1)
        #expect(ShoppingRepository.all(in: db.context).map(\.ingredientID).sorted() == ["egg", "milk", "rice"])
    }

    @Test func aRepeatInOneCallIsOnlyCountedOnce() throws {
        let db = try TestDatabase()
        #expect(ShoppingRepository.add([egg, egg], in: db.context) == 1)
    }

    @Test func tickingOffTogglesTheBasket() throws {
        let db = try TestDatabase()
        ShoppingRepository.add([egg], in: db.context)
        let item = try #require(ShoppingRepository.all(in: db.context).first)
        #expect(!item.isBought)
        ShoppingRepository.toggleBought(item, in: db.context)
        #expect(item.isBought)
        ShoppingRepository.toggleBought(item, in: db.context)
        #expect(!item.isBought)
    }

    @Test func theBasketMovesIntoThePantryWithoutDuplicates() throws {
        let db = try TestDatabase()
        PantryRepository.add([milk], in: db.context)
        ShoppingRepository.add([egg, rice, milk], in: db.context)
        for item in ShoppingRepository.all(in: db.context) where item.ingredientID != "rice" {
            ShoppingRepository.toggleBought(item, in: db.context)
        }
        #expect(ShoppingRepository.moveBoughtToPantry(in: db.context) == 2)
        #expect(ShoppingRepository.all(in: db.context).map(\.ingredientID) == ["rice"])
        #expect(PantryRepository.all(in: db.context).map(\.ingredientID).sorted() == ["egg", "milk"])
    }

    @Test func movingAnEmptyBasketDoesNothing() throws {
        let db = try TestDatabase()
        ShoppingRepository.add([egg], in: db.context)
        #expect(ShoppingRepository.moveBoughtToPantry(in: db.context) == 0)
        #expect(PantryRepository.all(in: db.context).isEmpty)
    }

    @Test func removingTakesItOffTheList() throws {
        let db = try TestDatabase()
        ShoppingRepository.add([egg, rice], in: db.context)
        let item = try #require(ShoppingRepository.all(in: db.context).first { $0.ingredientID == "egg" })
        ShoppingRepository.remove(item, in: db.context)
        #expect(ShoppingRepository.all(in: db.context).map(\.ingredientID) == ["rice"])
    }

    @Test func runOutThingsOnlyGoOnTheListWhenSwitchedOn() throws {
        let db = try TestDatabase()
        #expect(ShoppingRepository.addRunOut([egg], enabled: false, in: db.context) == 0)
        #expect(ShoppingRepository.all(in: db.context).isEmpty)
        #expect(ShoppingRepository.addRunOut([egg], enabled: true, in: db.context) == 1)
        #expect(ShoppingRepository.addRunOut([], enabled: true, in: db.context) == 0)
    }

    @Test func aRecipeAddsWhatItIsMissing() throws {
        let db = try TestDatabase()
        let match = try #require(RecipeMatcher.matches(pantry: ["rice", "egg", "soy-sauce"], maxMissing: .max)
            .first { $0.recipe.id == "egg-fried-rice" })
        #expect(ShoppingRepository.addMissing(from: match, in: db.context) == 1)
        #expect(ShoppingRepository.all(in: db.context).map(\.ingredientID) == ["frozen-veg"])
        #expect(ShoppingRepository.addMissing(from: match, in: db.context) == 0)
    }

    @Test func aCustomItemKeepsItsName() throws {
        let db = try TestDatabase()
        ShoppingRepository.add([ResolvedItem(customName: "kimchi")], in: db.context)
        let item = try #require(ShoppingRepository.all(in: db.context).first)
        #expect(item.name == "Kimchi" && item.isCustom)
    }

    @Test func theRecipeNudgeOnlyAppliesToOneOrTwoMissingThings() throws {
        let db = try TestDatabase()
        let recipe = try #require(RecipeStore.recipe(withID: "egg-fried-rice"))
        func nudge(_ pantry: Set<String>, listed: Set<String> = []) -> RecipeListAction? {
            let match = RecipeMatcher.matches(recipes: [recipe], pantry: pantry, maxMissing: .max)[0]
            return RecipeListAction.nudge(for: match, listed: listed, context: db.context)
        }
        #expect(nudge(["rice", "egg", "soy-sauce", "frozen-veg"]) == nil, "nothing missing")
        #expect(nudge([]) == nil, "too many missing")
        let one = try #require(nudge(["rice", "egg", "soy-sauce"]))
        let name = try #require(IngredientCatalog.ingredient(withID: "frozen-veg")).name.lowercased()
        #expect(one.title == "Add \(name) to my list")
        #expect(!one.isDone)
        #expect(try #require(nudge(["rice", "egg", "soy-sauce"], listed: ["frozen-veg"])).isDone)
    }
}
