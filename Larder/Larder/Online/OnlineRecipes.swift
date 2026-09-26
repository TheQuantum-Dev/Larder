//
//  OnlineRecipes.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation
import Observation

/// The recipes found online for what's in the pantry. Everything here is kept
/// in memory only and thrown away after 50 minutes, because the recipe
/// service's terms don't let an app keep its recipes for longer than an hour.
/// Only a recipe's id, name and photo link are ever saved (with a heart or a
/// thumb), and a saved one is fetched again when it's opened.
///
/// Nothing here can leave the app worse off: with no key, with the feature off,
/// offline, or with the day's free lookups used up, the bundled recipes carry
/// on exactly as before.
@Observable
@MainActor
final class OnlineRecipes {
    enum Status: Equatable {
        /// The person hasn't turned it on.
        case off
        /// This build has no key.
        case unavailable
        /// Nothing to look up yet, like an empty pantry.
        case idle
        case loading
        case ready
        /// The day's free lookups are used up.
        case exhausted
        case offline
        case failed
    }

    /// The service allows an hour; this stays well inside it.
    static let lifetime: TimeInterval = 50 * 60

    private(set) var status: Status

    private var latest: (recipes: [Recipe], fetchedAt: Date)?
    private var cache: [OnlineRequest: (recipes: [Recipe], fetchedAt: Date)] = [:]
    private var fetched: [String: (recipe: Recipe, fetchedAt: Date)] = [:]
    private var quota: OnlineQuota

    private let api: (any RecipeAPI)?
    private let clock: @Sendable () -> Date
    private let saveQuota: (OnlineQuota) -> Void
    private let settle: Duration

    init(api: (any RecipeAPI)? = OnlineRecipes.defaultAPI(),
         quota: OnlineQuota = OnlineQuotaStore.load(),
         saveQuota: @escaping (OnlineQuota) -> Void = { OnlineQuotaStore.save($0) },
         clock: @escaping @Sendable () -> Date = { Date() },
         settle: Duration = .milliseconds(800)) {
        self.api = api
        self.quota = quota
        self.saveQuota = saveQuota
        self.clock = clock
        self.settle = settle
        status = api == nil ? .unavailable : .idle
    }

    nonisolated static func defaultAPI() -> (any RecipeAPI)? {
        #if DEBUG
        if OnlineRecipeConfig.usesFakeAPI { return FakeRecipeAPI() }
        #endif
        return OnlineRecipeConfig.apiKey.map { SpoonacularClient(apiKey: $0) }
    }

    /// The recipes from the latest lookup, until they're too old to keep.
    var recipes: [Recipe] {
        guard let latest, clock().timeIntervalSince(latest.fetchedAt) < Self.lifetime else { return [] }
        return latest.recipes
    }

    /// Roughly how many of today's free points are left.
    var pointsLeft: Double { quota.remaining(on: clock()) }

    // MARK: - Looking things up

    /// Finds recipes for a request, unless the same one was answered recently.
    /// Calling it again with something new cancels the one before, and it waits
    /// a moment first, so a burst of pantry taps costs one lookup, not many.
    func refresh(_ request: OnlineRequest, enabled: Bool) async {
        guard api != nil else {
            status = .unavailable
            return
        }
        guard enabled else {
            forget()
            status = .off
            return
        }
        guard !request.anchors.isEmpty else {
            status = .idle
            return
        }
        dropExpired()
        if let hit = cache[request] {
            latest = hit
            status = .ready
            return
        }

        try? await Task.sleep(for: settle)
        guard !Task.isCancelled, let api else { return }

        let nutrientFilter = OnlineQuery.usesNutrientFilter(request)
        let estimate = OnlineQuota.searchCost(recipes: request.number, nutrientFilter: nutrientFilter)
        guard quota.canSpend(estimate, on: clock()) else {
            status = .exhausted
            return
        }

        status = .loading
        do {
            var outcome = try await api.search(request)
            charge(outcome.pointsCharged ?? OnlineQuota.searchCost(recipes: outcome.recipes.count,
                                                                    nutrientFilter: nutrientFilter),
                   serviceCount: outcome.quotaUsed)
            // Nothing found around two ingredients: try again around one.
            if outcome.recipes.isEmpty, request.anchors.count > 1, quota.canSpend(estimate, on: clock()) {
                var narrower = request
                narrower.anchors = Array(request.anchors.prefix(1))
                outcome = try await api.search(narrower)
                charge(outcome.pointsCharged ?? OnlineQuota.searchCost(recipes: outcome.recipes.count,
                                                                        nutrientFilter: nutrientFilter),
                       serviceCount: outcome.quotaUsed)
            }
            let entry = (recipes: outcome.recipes.compactMap(OnlineRecipeMapper.recipe(from:)), fetchedAt: clock())
            cache[request] = entry
            latest = entry
            status = .ready
        } catch is CancellationError {
            status = latest == nil ? .idle : .ready
        } catch OnlineError.quotaExceeded {
            quota.markExhausted(on: clock())
            saveQuota(quota)
            status = .exhausted
        } catch OnlineError.offline {
            status = .offline
        } catch {
            status = .failed
        }
    }

    /// One saved recipe, fetched again by its id (a favorite's recipe isn't kept
    /// between sessions). Nil if it can't be reached right now.
    func recipe(id: String) async -> Recipe? {
        dropExpired()
        if let recipe = latest?.recipes.first(where: { $0.id == id }) ?? fetched[id]?.recipe { return recipe }
        guard let api, id.hasPrefix(OnlineRecipeMapper.idPrefix),
              let number = Int(id.dropFirst(OnlineRecipeMapper.idPrefix.count)),
              quota.canSpend(OnlineQuota.recipeFetch, on: clock()) else { return nil }
        do {
            let dto = try await api.recipe(id: number)
            charge(OnlineQuota.recipeFetch)
            guard let recipe = OnlineRecipeMapper.recipe(from: dto) else { return nil }
            fetched[id] = (recipe, clock())
            return recipe
        } catch OnlineError.quotaExceeded {
            quota.markExhausted(on: clock())
            saveQuota(quota)
            return nil
        } catch {
            return nil
        }
    }

    // MARK: - Housekeeping

    /// Counts the points a lookup used. When the service also says how many the day
    /// has used in all, that count wins if it's higher, so ours can't fall behind.
    private func charge(_ points: Double, serviceCount: Double? = nil) {
        quota.record(points, on: clock())
        if let serviceCount { quota.sync(used: serviceCount, on: clock()) }
        saveQuota(quota)
    }

    /// Lets go of anything older than the service allows.
    private func dropExpired() {
        let now = clock()
        cache = cache.filter { now.timeIntervalSince($0.value.fetchedAt) < Self.lifetime }
        fetched = fetched.filter { now.timeIntervalSince($0.value.fetchedAt) < Self.lifetime }
    }

    /// Turning the feature off means holding none of its recipes.
    private func forget() {
        latest = nil
        cache = [:]
        fetched = [:]
    }
}
