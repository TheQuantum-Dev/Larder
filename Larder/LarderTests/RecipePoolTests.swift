//
//  RecipePoolTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/26/26.
//

import Testing
@testable import Larder

struct RecipePoolTests {
    private let pantry: Set<String> = ["egg", "rice", "bread"]

    private func recipe(_ id: String, needs ids: [String], online: Bool) -> Recipe {
        Recipe(id: id, title: id, emoji: "🍽️", minutes: 10, servings: 1, equipment: [],
               ingredients: ids.map { RecipeIngredient(id: $0, amount: $0, qty: 1, optional: nil, alt: nil) },
               steps: [RecipeStep(text: "Cook it.", timer: nil)], tip: "Enjoy.", healthy: false,
               source: online ? RecipeSource(name: "Somewhere", url: nil, credit: nil) : nil)
    }

    private var bundled: [Recipe] {
        [recipe("toast", needs: ["bread"], online: false), recipe("rice-bowl", needs: ["rice", "onion"], online: false)]
    }

    private func pool(online: [Recipe], onlineOnly: Bool) -> [RecipeMatch] {
        RecipePool.matches(bundled: bundled, online: online, onlineOnly: onlineOnly) { recipes in
            RecipeMatcher.matches(recipes: recipes, pantry: pantry, maxMissing: .max)
        }
    }

    @Test func onlineRecipesAreRankedInAmongLarderOwn() {
        let ready = recipe("sp-1", needs: ["egg", "rice"], online: true)
        let ids = pool(online: [ready], onlineOnly: false).map(\.id)
        #expect(Set(ids) == ["toast", "rice-bowl", "sp-1"])
        // Ready ones come before the one that's missing an onion, wherever they came from.
        #expect(ids.last == "rice-bowl")
    }

    @Test func onlineOnlyKeepsJustTheOnlineOnes() {
        let ids = pool(online: [recipe("sp-1", needs: ["egg"], online: true)], onlineOnly: true).map(\.id)
        #expect(ids == ["sp-1"])
    }

    @Test func onlineOnlyFallsBackToLarderOwnWhenThereAreNone() {
        #expect(pool(online: [], onlineOnly: true).count == 2)
    }

    @Test func anOnlineRecipeNeedingABigShopIsLeftOut() {
        let bigShop = recipe("sp-2", needs: ["a", "b", "c", "d", "e", "f", "g"], online: true)
        let fine = recipe("sp-3", needs: ["a", "b", "c", "d", "e", "f"], online: true)
        let ids = Set(pool(online: [bigShop, fine], onlineOnly: false).map(\.id))
        #expect(!ids.contains("sp-2"))
        #expect(ids.contains("sp-3"))
        // And if that leaves nothing online, "only online" still shows Larder's own.
        #expect(pool(online: [bigShop], onlineOnly: true).count == 2)
    }

    @Test func theOnlineChipKeepsOnlyOnlineRecipes() {
        let matches = pool(online: [recipe("sp-1", needs: ["egg"], online: true)], onlineOnly: false)
        #expect(RecipeFilter.apply(.online, query: "", to: matches).map(\.id) == ["sp-1"])
    }

    @Test func theOnlineChipOnlyShowsWhileOnlineRecipesAreOn() {
        #expect(!RecipeFilter.available(showsNutrition: true).contains(.online))
        #expect(RecipeFilter.available(showsNutrition: true, offersOnline: true).contains(.online))
        #expect(RecipeFilter.available(showsNutrition: false, offersOnline: true).contains(.online))
    }
}
