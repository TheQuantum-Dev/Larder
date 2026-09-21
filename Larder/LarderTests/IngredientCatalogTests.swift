//
//  IngredientCatalogTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/20/26.
//

import Testing
@testable import Larder

@MainActor
struct IngredientCatalogTests {

    @Test func keysIgnoreCasePunctuationAndPlurals() {
        #expect(IngredientCatalog.key(for: "Purple Onions!") == IngredientCatalog.key(for: "purple onion"))
        #expect(IngredientCatalog.key(for: "Tomatoes") == IngredientCatalog.key(for: "tomato"))
        #expect(IngredientCatalog.key(for: "berries") == IngredientCatalog.key(for: "berry"))
    }

    @Test func namesResolveToCatalogIngredients() {
        #expect(IngredientCatalog.resolve("eggs")?.id == "egg")
        #expect(IngredientCatalog.resolve("Tomatoes")?.id == "tomato")
        #expect(IngredientCatalog.resolve("hummus")?.id == "hummus")
        #expect(IngredientCatalog.resolve("jalapeño")?.id == "jalapeno")
    }

    @Test func extraWordsFallBackToTheMainNoun() {
        #expect(IngredientCatalog.resolve("purple onion")?.id == "onion")
        #expect(IngredientCatalog.resolve("whole milk")?.id == "milk")
        #expect(IngredientCatalog.resolve("organic baby spinach")?.id == "spinach")
    }

    @Test func multiWordAliasesBeatTheirLastWord() {
        #expect(IngredientCatalog.resolve("peanut butter")?.id == "peanut-butter")
        #expect(IngredientCatalog.resolve("olive oil")?.id == "olive-oil")
        #expect(IngredientCatalog.resolve("sweet potato")?.id == "sweet-potato")
    }

    @Test func unknownFoodsBecomeCustomItems() {
        let item = IngredientCatalog.resolve("dragon fruit")
        #expect(item?.isCustom == true)
        #expect(item?.name == "Dragon fruit")
    }

    @Test func containerWordsAreStrippedFromRealFoods() {
        #expect(IngredientCatalog.resolve("milk carton")?.id == "milk")
        #expect(IngredientCatalog.resolve("jar of olives")?.id == "olives")
    }

    @Test func vagueWordsAreNotItems() {
        #expect(IngredientCatalog.resolve("fruit") == nil)
        #expect(IngredientCatalog.resolve("Sauce") == nil)
        #expect(IngredientCatalog.resolve("vegetables") == nil)
        #expect(IngredientCatalog.resolve("white") == nil)
        #expect(IngredientCatalog.resolve("yellow") == nil)
    }

    @Test func nonFoodAndEmptyNamesAreDropped() {
        #expect(IngredientCatalog.resolve("container") == nil)
        #expect(IngredientCatalog.resolve("glass jar") == nil)
        #expect(IngredientCatalog.resolve("   ") == nil)
    }

    @Test func textSearchFindsLongerNamesFirst() {
        let found = IngredientCatalog.find(inText: "CREAMY PEANUT BUTTER 16 OZ")
        #expect(found.contains { $0.id == "peanut-butter" })
        #expect(!found.contains { $0.id == "butter" })
    }

    @Test func manualSearchMatchesPrefixes() {
        #expect(IngredientCatalog.search("chick").contains { $0.id == "chicken" })
        #expect(IngredientCatalog.search("").isEmpty)
    }

    @Test func everyIngredientHasAUniqueId() {
        let ids = IngredientCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func quickAddListResolvesEveryEntry() {
        #expect(IngredientCatalog.quickAdd.count == 24)
    }
}
