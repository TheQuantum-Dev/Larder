//
//  RecipeNoteTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation
import Testing
@testable import Larder

@MainActor
struct RecipeNoteTests {
    private let pasta = RecipeRef(id: "simple-tomato-pasta", title: "Simple tomato pasta", emoji: "🍝")
    private let rice = RecipeRef(id: "egg-fried-rice", title: "Egg fried rice", emoji: "🍚")

    private func note(_ ref: RecipeRef, in db: TestDatabase) -> RecipeNote? {
        RecipeNoteRepository.note(for: ref.id, in: db.context)
    }

    @Test func aHeartTogglesOnAndOff() throws {
        let db = try TestDatabase()
        RecipeNoteRepository.toggleFavorite(pasta, in: db.context)
        #expect(note(pasta, in: db)?.isFavorite == true)
        RecipeNoteRepository.toggleFavorite(pasta, in: db.context)
        // With nothing left to say, the note goes away.
        #expect(note(pasta, in: db) == nil)
    }

    @Test func aThumbIsTakenBackByTappingItAgain() throws {
        let db = try TestDatabase()
        RecipeNoteRepository.setVerdict(.up, for: pasta, in: db.context)
        #expect(note(pasta, in: db)?.verdict == .up)
        RecipeNoteRepository.setVerdict(.up, for: pasta, in: db.context)
        #expect(note(pasta, in: db) == nil)
    }

    @Test func aDifferentThumbReplacesTheFirst() throws {
        let db = try TestDatabase()
        RecipeNoteRepository.setVerdict(.up, for: pasta, in: db.context)
        RecipeNoteRepository.setVerdict(.down, for: pasta, in: db.context)
        #expect(note(pasta, in: db)?.verdict == .down)
        #expect(RecipeNoteRepository.all(in: db.context).count == 1)
    }

    @Test func theHeartAndTheThumbAreIndependent() throws {
        let db = try TestDatabase()
        RecipeNoteRepository.toggleFavorite(pasta, in: db.context)
        RecipeNoteRepository.setVerdict(.up, for: pasta, in: db.context)
        RecipeNoteRepository.setVerdict(.up, for: pasta, in: db.context)
        // The thumb was taken back, but the heart is still there.
        #expect(note(pasta, in: db)?.isFavorite == true)
        #expect(note(pasta, in: db)?.verdict == nil)

        RecipeNoteRepository.setVerdict(.down, for: pasta, in: db.context)
        RecipeNoteRepository.toggleFavorite(pasta, in: db.context)
        #expect(note(pasta, in: db)?.isFavorite == false)
        #expect(note(pasta, in: db)?.verdict == .down)
    }

    @Test func mostRecentlyTouchedComesFirst() throws {
        let db = try TestDatabase()
        let start = Date(timeIntervalSince1970: 1_000_000)
        RecipeNoteRepository.toggleFavorite(pasta, in: db.context, at: start)
        RecipeNoteRepository.toggleFavorite(rice, in: db.context, at: start.addingTimeInterval(60))
        #expect(RecipeNoteRepository.all(in: db.context).map(\.recipeID) == [rice.id, pasta.id])
    }

    @Test func aNoteKeepsTheLatestName() throws {
        let db = try TestDatabase()
        RecipeNoteRepository.toggleFavorite(pasta, in: db.context)
        let renamed = RecipeRef(id: pasta.id, title: "Tomato pasta", emoji: "🍅")
        RecipeNoteRepository.setVerdict(.up, for: renamed, in: db.context)
        #expect(note(pasta, in: db)?.title == "Tomato pasta")
        #expect(note(pasta, in: db)?.emoji == "🍅")
    }

    @Test func aRecipeAndItsMealSummaryAgreeOnTheirRef() throws {
        let recipe = try #require(RecipeStore.recipe(withID: "egg-fried-rice"))
        let summary = MealSummary(recipe: recipe, orderOutPrice: 14)
        #expect(RecipeRef(recipe) == RecipeRef(summary))
    }
}

@MainActor
struct RecipeTasteTests {
    private func recipe(_ id: String, lines: [RecipeIngredient]) -> Recipe {
        Recipe(id: id, title: id, emoji: "🍽️", minutes: 10, servings: 1, equipment: [],
               ingredients: lines, steps: [RecipeStep(text: "Cook it.", timer: nil)], tip: "Enjoy.", healthy: false)
    }

    private func line(_ id: String) -> RecipeIngredient {
        RecipeIngredient(id: id, amount: id, qty: 1, optional: nil, alt: nil)
    }

    // MARK: - The numbers

    @Test func nothingChangesWithoutAnyTaste() {
        #expect(RecipeTaste.none.adjustment(for: "anything") == 0)
    }

    @Test func aHeartOrAThumbsUpLiftsARecipe() {
        let taste = RecipeTaste(favorites: ["a"], liked: ["b"])
        #expect(taste.adjustment(for: "a") == -RecipeTaste.likedBoost)
        #expect(taste.adjustment(for: "b") == -RecipeTaste.likedBoost)
        // Both together don't stack.
        #expect(RecipeTaste(favorites: ["a"], liked: ["a"]).adjustment(for: "a") == -RecipeTaste.likedBoost)
    }

    @Test func aThumbsDownBeatsAHeart() {
        let taste = RecipeTaste(favorites: ["a"], disliked: ["a"])
        #expect(taste.adjustment(for: "a") == RecipeTaste.dislikedPenalty)
    }

    @Test func somethingCookedLatelyIsNudgedDown() {
        #expect(RecipeTaste(recent: ["a"]).adjustment(for: "a") == RecipeTaste.recentPenalty)
    }

    @Test func recentMeansTodayAndYesterday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 9))!
        func at(day: Int, hour: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
        }
        let cooked = [(id: "today", date: at(day: 25, hour: 8)),
                      (id: "yesterday-late", date: at(day: 24, hour: 23)),
                      (id: "yesterday-early", date: at(day: 24, hour: 0)),
                      (id: "two-days-ago", date: at(day: 23, hour: 20))]
        #expect(RecipeTaste.recentIDs(cooked: cooked, now: now, calendar: calendar)
                == ["today", "yesterday-late", "yesterday-early"])
    }

    @Test func tasteIsReadFromTheSavedNotes() throws {
        let db = try TestDatabase()
        let loved = RecipeRef(id: "loved", title: "Loved", emoji: "🍜")
        let hated = RecipeRef(id: "hated", title: "Hated", emoji: "🥣")
        RecipeNoteRepository.setVerdict(.up, for: loved, in: db.context)
        RecipeNoteRepository.toggleFavorite(loved, in: db.context)
        RecipeNoteRepository.setVerdict(.down, for: hated, in: db.context)
        let taste = RecipeTaste(notes: RecipeNoteRepository.all(in: db.context), recent: ["x"])
        #expect(taste.favorites == ["loved"])
        #expect(taste.liked == ["loved"])
        #expect(taste.disliked == ["hated"])
        #expect(taste.recent == ["x"])
    }

    // MARK: - In the matcher

    @Test func tasteBreaksATieBetweenEquallyReadyRecipes() {
        let recipes = [recipe("a", lines: [line("egg")]), recipe("b", lines: [line("egg")])]
        let plain = RecipeMatcher.matches(recipes: recipes, pantry: ["egg"])
        #expect(plain.map(\.id) == ["a", "b"])   // no taste: the title breaks the tie
        let liked = RecipeMatcher.matches(recipes: recipes, pantry: ["egg"], taste: RecipeTaste(liked: ["b"]))
        #expect(liked.map(\.id) == ["b", "a"])
    }

    @Test func aThumbsDownSinksARecipeButNeverHidesIt() {
        let recipes = [recipe("a", lines: [line("egg")]), recipe("b", lines: [line("egg")])]
        let matches = RecipeMatcher.matches(recipes: recipes, pantry: ["egg"], taste: RecipeTaste(disliked: ["a"]))
        #expect(matches.map(\.id) == ["b", "a"])
    }

    @Test func tasteNeverBeatsBeingReady() {
        let ready = recipe("ready", lines: [line("egg")])
        let oneAway = recipe("one-away", lines: [line("egg"), line("rice")])
        let taste = RecipeTaste(favorites: ["one-away"], liked: ["one-away"], disliked: ["ready"])
        let matches = RecipeMatcher.matches(recipes: [oneAway, ready], pantry: ["egg"], taste: taste)
        #expect(matches.map(\.id) == ["ready", "one-away"])
    }
}
