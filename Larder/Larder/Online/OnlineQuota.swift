//
//  OnlineQuota.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation

/// A running count of how much of the free plan's daily allowance this phone
/// has used, so lookups stop before the day's points do. The service's day
/// starts at midnight UTC, so that's the day used here.
nonisolated struct OnlineQuota: Codable, Equatable, Sendable {
    static let dailyPoints = 50.0
    /// Lookups stop here, leaving a few points spare for fetching a saved recipe.
    static let stopAt = 45.0
    /// A search costs 1 point, plus this much for each recipe returned with its
    /// details, nutrition and ingredients, plus 1 more when it filters on
    /// calories or protein.
    static let perRecipe = 0.085
    /// Fetching one saved recipe, with its nutrition.
    static let recipeFetch = 1.1

    /// Which day the numbers are for, like "2026-09-26", in UTC.
    var day = ""
    var used = 0.0
    /// Set when the service itself says the day's points are gone.
    var exhausted = false

    static func dayKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func searchCost(recipes: Int, nutrientFilter: Bool) -> Double {
        1 + Double(recipes) * perRecipe + (nutrientFilter ? 1 : 0)
    }

    /// The same numbers, or a fresh day's if the day has changed.
    func current(on date: Date) -> OnlineQuota {
        day == Self.dayKey(for: date) ? self : OnlineQuota(day: Self.dayKey(for: date))
    }

    func canSpend(_ points: Double, on date: Date) -> Bool {
        let today = current(on: date)
        return !today.exhausted && today.used + points <= Self.stopAt
    }

    /// Roughly how many points are left today, for showing in Settings.
    func remaining(on date: Date) -> Double {
        let today = current(on: date)
        return today.exhausted ? 0 : max(0, Self.dailyPoints - today.used)
    }

    mutating func record(_ points: Double, on date: Date) {
        self = current(on: date)
        used += points
    }

    /// Takes the service's own count of today's points, if it's higher than ours.
    mutating func sync(used serviceUsed: Double, on date: Date) {
        self = current(on: date)
        used = max(used, serviceUsed)
    }

    mutating func markExhausted(on date: Date) {
        self = current(on: date)
        exhausted = true
        used = max(used, Self.dailyPoints)
    }
}

nonisolated enum OnlineQuotaStore {
    static let key = "onlineQuota"

    static func load(from defaults: UserDefaults = .standard) -> OnlineQuota {
        #if DEBUG
        // `-resetOnlineQuota YES` starts each launch with the day's lookups unspent (debug builds only).
        if UserDefaults.standard.bool(forKey: "resetOnlineQuota") { defaults.removeObject(forKey: key) }
        #endif
        guard let data = defaults.data(forKey: key),
              let quota = try? JSONDecoder().decode(OnlineQuota.self, from: data) else { return OnlineQuota() }
        return quota
    }

    static func save(_ quota: OnlineQuota, to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(quota) { defaults.set(data, forKey: key) }
    }
}
