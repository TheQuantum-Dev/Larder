//
//  CookingStreak.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import Foundation

/// How many days in a row the person has cooked at least one meal. A day
/// isn't over until midnight, so not having cooked *yet* today never breaks
/// the streak: it just puts it at risk.
nonisolated enum CookingStreak {
    enum Status: Equatable {
        /// Nothing going right now.
        case none
        /// Cooked today, so the streak is safe until tomorrow.
        case safe(days: Int)
        /// Cooked yesterday but not yet today: still alive, ends at midnight.
        case atRisk(days: Int)

        var days: Int {
            switch self {
            case .none: 0
            case .safe(let days), .atRisk(let days): days
            }
        }
    }

    static func status(from dates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Status {
        let days = cookedDays(dates, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        if days.contains(today) {
            return .safe(days: run(endingOn: today, in: days, calendar: calendar))
        }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              days.contains(yesterday) else { return .none }
        return .atRisk(days: run(endingOn: yesterday, in: days, calendar: calendar))
    }

    /// The longest run ever, for Insights.
    static func best(from dates: [Date], calendar: Calendar = .current) -> Int {
        let days = cookedDays(dates, calendar: calendar).sorted()
        var best = 0
        var current = 0
        var previous: Date?
        for day in days {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
            previous = day
        }
        return best
    }

    private static func cookedDays(_ dates: [Date], calendar: Calendar) -> Set<Date> {
        Set(dates.map { calendar.startOfDay(for: $0) })
    }

    private static func run(endingOn last: Date, in days: Set<Date>, calendar: Calendar) -> Int {
        var count = 0
        var day = last
        while days.contains(day) {
            count += 1
            guard let before = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = before
        }
        return count
    }
}
