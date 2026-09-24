//
//  RecipeFilterTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/24/26.
//

import Testing
@testable import Larder

struct RecipeFilterTests {
    private let everything = RecipeMatcher.matches(pantry: ["egg", "rice", "frozen-veg", "soy-sauce", "bread", "cheese"],
                                                   maxMissing: .max)

    @Test func allShowsTheWholeBookInMatcherOrder() {
        let shown = RecipeFilter.apply(.all, query: "", to: everything)
        #expect(shown.map(\.id) == everything.map(\.id))
        #expect(shown.count == RecipeStore.all.count)
    }

    @Test func eachFilterOnlyKeepsWhatItSays() {
        #expect(RecipeFilter.apply(.ready, query: "", to: everything).allSatisfy { $0.isReady })
        #expect(RecipeFilter.apply(.quick, query: "", to: everything).allSatisfy { $0.recipe.minutes <= RecipeFilter.quickMinutes })
        #expect(RecipeFilter.apply(.cheap, query: "", to: everything)
            .allSatisfy { $0.recipe.costPerServing <= RecipeFilter.cheapPerServing })
        #expect(RecipeFilter.apply(.noStove, query: "", to: everything).allSatisfy { $0.recipe.needsNoStove })
    }

    @Test func searchMatchesTitlesWithoutCaringAboutCase() {
        let shown = RecipeFilter.apply(.all, query: "  FRIED rice ", to: everything)
        #expect(shown.map(\.id) == ["egg-fried-rice"])
    }

    @Test func searchAndFilterCombine() {
        #expect(RecipeFilter.apply(.noStove, query: "fried rice", to: everything).isEmpty)
    }
}
