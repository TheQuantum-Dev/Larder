//
//  OnlineRecipesServiceTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation
import Testing
@testable import Larder

/// A recipe service that answers from a script and counts how often it's asked.
private final class StubAPI: RecipeAPI, @unchecked Sendable {
    var searchCalls: [OnlineRequest] = []
    var recipeCalls: [Int] = []
    var searchResults: [Result<OnlineSearchOutcome, OnlineError>] = []
    var recipeResult: Result<OnlineRecipeDTO, OnlineError> = .failure(.badResponse)

    static let samples: [OnlineRecipeDTO] = {
        let data = Data(FakeRecipeAPI.sampleJSON.utf8)
        return (try? JSONDecoder().decode(OnlineSearchResponse.self, from: data).results) ?? []
    }()

    func search(_ request: OnlineRequest) async throws -> OnlineSearchOutcome {
        searchCalls.append(request)
        let next = searchResults.isEmpty ? .success(OnlineSearchOutcome(recipes: Self.samples, pointsCharged: 2.6))
                                         : searchResults.removeFirst()
        return try next.get()
    }

    func recipe(id: Int) async throws -> OnlineRecipeDTO {
        recipeCalls.append(id)
        return try recipeResult.get()
    }
}

/// A clock the test can move.
private final class SteppingClock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 1_790_000_000)
}

@MainActor
struct OnlineRecipesServiceTests {
    private let request = OnlineRequest(anchors: ["chicken", "rice"], goal: .buildMuscle, diets: [], slot: .dinner)

    private final class Saved: @unchecked Sendable { var quota: OnlineQuota? }

    private func service(_ api: StubAPI?, quota: OnlineQuota = OnlineQuota(), clock: SteppingClock = SteppingClock(),
                         saved: Saved = Saved()) -> OnlineRecipes {
        OnlineRecipes(api: api, quota: quota, saveQuota: { saved.quota = $0 }, clock: { clock.now }, settle: .zero)
    }

    @Test func withNoKeyItIsUnavailableAndNeverAsks() async {
        let online = service(nil)
        await online.refresh(request, enabled: true)
        #expect(online.status == .unavailable)
        #expect(online.recipes.isEmpty)
    }

    @Test func switchedOffItDoesNothing() async {
        let api = StubAPI()
        let online = service(api)
        await online.refresh(request, enabled: false)
        #expect(online.status == .off)
        #expect(api.searchCalls.isEmpty)
    }

    @Test func aLookupFillsInRecipesAndCountsThePoints() async {
        let api = StubAPI()
        let saved = Saved()
        let online = service(api, saved: saved)
        await online.refresh(request, enabled: true)
        #expect(online.status == .ready)
        #expect(online.recipes.count == 6)
        let allOnline = online.recipes.allSatisfy { $0.isOnline }
        #expect(allOnline)
        #expect(api.searchCalls == [request])
        #expect(abs((saved.quota?.used ?? 0) - 2.6) < 0.001)
    }

    @Test func theSameQuestionTwiceIsAnsweredFromMemory() async {
        let api = StubAPI()
        let online = service(api)
        await online.refresh(request, enabled: true)
        await online.refresh(request, enabled: true)
        #expect(api.searchCalls.count == 1)
        #expect(online.status == .ready)
    }

    @Test func aDifferentQuestionAsksAgain() async {
        let api = StubAPI()
        let online = service(api)
        await online.refresh(request, enabled: true)
        var lunch = request
        lunch.slot = .lunch
        await online.refresh(lunch, enabled: true)
        #expect(api.searchCalls.count == 2)
    }

    @Test func recipesAreLetGoOfAfterFiftyMinutes() async {
        let api = StubAPI()
        let clock = SteppingClock()
        let online = service(api, clock: clock)
        await online.refresh(request, enabled: true)
        #expect(!online.recipes.isEmpty)

        clock.now.addTimeInterval(49 * 60)
        #expect(!online.recipes.isEmpty)
        clock.now.addTimeInterval(2 * 60)
        #expect(online.recipes.isEmpty)

        // Asking again goes back to the service rather than to a stale copy.
        await online.refresh(request, enabled: true)
        #expect(api.searchCalls.count == 2)
        #expect(!online.recipes.isEmpty)
    }

    @Test func turningItOffForgetsEverything() async {
        let online = service(StubAPI())
        await online.refresh(request, enabled: true)
        await online.refresh(request, enabled: false)
        #expect(online.recipes.isEmpty)
        #expect(online.status == .off)
    }

    @Test func theServicesOwnCountOfPointsUsedIsTrusted() async {
        let api = StubAPI()
        api.searchResults = [.success(OnlineSearchOutcome(recipes: StubAPI.samples, pointsCharged: 2.6, quotaUsed: 33))]
        let saved = Saved()
        let online = service(api, saved: saved)
        await online.refresh(request, enabled: true)
        #expect(abs((saved.quota?.used ?? 0) - 33) < 0.001)
        #expect(online.pointsLeft < 17.5)
    }

    @Test func nothingIsAskedOnceTheDaysPointsAreSpent() async {
        let api = StubAPI()
        var quota = OnlineQuota()
        quota.record(44, on: SteppingClock().now)
        let online = service(api, quota: quota)
        await online.refresh(request, enabled: true)
        #expect(online.status == .exhausted)
        #expect(api.searchCalls.isEmpty)
        #expect(online.recipes.isEmpty)
    }

    @Test func theServiceSayingNoMoreStopsLookupsForTheDay() async {
        let api = StubAPI()
        api.searchResults = [.failure(.quotaExceeded)]
        let saved = Saved()
        let clock = SteppingClock()
        let online = service(api, clock: clock, saved: saved)
        await online.refresh(request, enabled: true)
        #expect(online.status == .exhausted)
        #expect(saved.quota?.exhausted == true)

        var other = request
        other.slot = .lunch
        await online.refresh(other, enabled: true)
        #expect(api.searchCalls.count == 1)   // no second try

        // Tomorrow it tries again.
        clock.now.addTimeInterval(86_400)
        await online.refresh(other, enabled: true)
        #expect(api.searchCalls.count == 2)
    }

    @Test func offlineAndFailuresKeepTheirOwnStatusAndDoNoHarm() async {
        let api = StubAPI()
        api.searchResults = [.failure(.offline), .failure(.badResponse), .failure(.unauthorized)]
        let online = service(api)
        await online.refresh(request, enabled: true)
        #expect(online.status == .offline)
        var second = request
        second.slot = .lunch
        await online.refresh(second, enabled: true)
        #expect(online.status == .failed)
        var third = request
        third.slot = .breakfast
        await online.refresh(third, enabled: true)
        #expect(online.status == .failed)
        #expect(online.recipes.isEmpty)
    }

    @Test func aFailureKeepsWhatWasAlreadyFound() async {
        let api = StubAPI()
        let online = service(api)
        await online.refresh(request, enabled: true)
        api.searchResults = [.failure(.offline)]
        var lunch = request
        lunch.slot = .lunch
        await online.refresh(lunch, enabled: true)
        #expect(online.status == .offline)
        #expect(online.recipes.count == 6)
    }

    @Test func nothingFoundAroundTwoIngredientsTriesOne() async {
        let api = StubAPI()
        api.searchResults = [.success(OnlineSearchOutcome(recipes: [], pointsCharged: 1.5)),
                             .success(OnlineSearchOutcome(recipes: StubAPI.samples, pointsCharged: 2.6))]
        let online = service(api)
        await online.refresh(request, enabled: true)
        #expect(api.searchCalls.map(\.anchors) == [["chicken", "rice"], ["chicken"]])
        #expect(online.recipes.count == 6)
    }

    @Test func aPantryWithNothingToBuildAroundAsksForNothing() async {
        let api = StubAPI()
        let online = service(api)
        var empty = request
        empty.anchors = []
        await online.refresh(empty, enabled: true)
        #expect(online.status == .idle)
        #expect(api.searchCalls.isEmpty)
    }

    // MARK: - Fetching a saved recipe again

    @Test func aRecipeAlreadyInMemoryIsNotFetchedAgain() async {
        let api = StubAPI()
        let online = service(api)
        await online.refresh(request, enabled: true)
        let found = await online.recipe(id: "sp-900001")
        #expect(found?.title == "Sesame chicken rice bowl")
        #expect(api.recipeCalls.isEmpty)
    }

    @Test func aSavedRecipeIsFetchedByIdOnceAndThenRemembered() async {
        let api = StubAPI()
        api.recipeResult = .success(StubAPI.samples[1])
        let online = service(api)
        let first = await online.recipe(id: "sp-900002")
        let second = await online.recipe(id: "sp-900002")
        #expect(first?.id == "sp-900002")
        #expect(second?.id == "sp-900002")
        #expect(api.recipeCalls == [900002])
    }

    @Test func aRecipeCannotBeFetchedWithoutPointsOrForABundledId() async {
        let api = StubAPI()
        api.recipeResult = .success(StubAPI.samples[0])
        var quota = OnlineQuota()
        quota.record(44.5, on: SteppingClock().now)
        let broke = service(api, quota: quota)
        #expect(await broke.recipe(id: "sp-900001") == nil)

        let online = service(api)
        #expect(await online.recipe(id: "egg-fried-rice") == nil)
        #expect(await online.recipe(id: "sp-notanumber") == nil)
        #expect(api.recipeCalls.isEmpty)
    }
}
