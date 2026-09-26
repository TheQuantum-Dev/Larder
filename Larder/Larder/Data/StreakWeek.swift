//
//  StreakWeek.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation

/// The seven days of this week, and which of them have a cooked meal. It's the
/// row of little Nutmegs that fill in as the week goes on.
nonisolated struct StreakWeek: Equatable, Sendable {
    enum State: Equatable, Sendable {
        /// Something was cooked that day, today included.
        case cooked
        /// Today, and nothing cooked yet.
        case today
        /// A day already gone this week with nothing cooked. Just a quiet
        /// outline: a missed day is never marked as a failure.
        case missed
        /// A day still to come.
        case upcoming
    }

    struct Day: Equatable, Identifiable, Sendable {
        /// Midnight at the start of that day.
        let date: Date
        let state: State
        let isToday: Bool

        var id: Date { date }
    }

    /// Seven days, in the order the person's calendar runs its week.
    let days: [Day]

    var cookedCount: Int { days.filter { $0.state == .cooked }.count }
    var isPerfect: Bool { !days.isEmpty && cookedCount == days.count }

    static func make(cookedDates: [Date], now: Date = Date(), calendar: Calendar = .current) -> StreakWeek {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return StreakWeek(days: []) }
        let today = calendar.startOfDay(for: now)
        let cooked = Set(cookedDates.map { calendar.startOfDay(for: $0) })

        let days = (0..<7).compactMap { offset -> Day? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
            let state: State
            if cooked.contains(date) {
                state = .cooked
            } else if date == today {
                state = .today
            } else if date < today {
                state = .missed
            } else {
                state = .upcoming
            }
            return Day(date: date, state: state, isToday: date == today)
        }
        return StreakWeek(days: days)
    }
}

/// The streak lengths worth celebrating, and the line that points at the next one.
nonisolated enum StreakMilestone {
    static let steps = [3, 7, 14, 30, 60, 100]

    static func isMilestone(_ days: Int) -> Bool { steps.contains(days) }

    /// The next milestone above this streak; nil once they're all behind.
    static func next(after days: Int) -> Int? { steps.first { $0 > days } }

    /// "2 more days to a 7-day streak", or nil past the last milestone. While
    /// the Coral look is still ahead, the first milestone says so.
    static func line(days: Int, coralEarned: Bool) -> String? {
        guard let next = next(after: days) else { return nil }
        let left = next - days
        let count = "\(left) more \(left == 1 ? "day" : "days")"
        if next == NutmegLook.coralStreak, !coralEarned {
            return "\(count) to unlock Coral Nutmeg"
        }
        return "\(count) to a \(next)-day streak"
    }
}

/// What cooking one more meal did to the streak, for the celebration after it.
nonisolated struct StreakProgress: Equatable, Sendable {
    /// The streak with this meal counted.
    let days: Int
    let week: StreakWeek
    /// True when this is the first meal of the day, so today's Nutmeg just woke up.
    let isNewDay: Bool
    /// Set when this meal made a milestone-length streak.
    let milestone: Int?
    /// Whether the Coral look has been earned by now, which changes what the
    /// line about the next milestone says.
    let coralEarned: Bool

    static func after(cookingAt date: Date, previousDates: [Date], calendar: Calendar = .current) -> StreakProgress {
        let dates = previousDates + [date]
        let today = calendar.startOfDay(for: date)
        let isNewDay = !previousDates.contains { calendar.startOfDay(for: $0) == today }
        let days = CookingStreak.status(from: dates, now: date, calendar: calendar).days
        let coralEarned = NutmegLook.earned(bestStreak: CookingStreak.best(from: dates, calendar: calendar),
                                            mealCount: dates.count).contains(.coral)
        return StreakProgress(days: days,
                              week: StreakWeek.make(cookedDates: dates, now: date, calendar: calendar),
                              isNewDay: isNewDay,
                              milestone: isNewDay && StreakMilestone.isMilestone(days) ? days : nil,
                              coralEarned: coralEarned)
    }
}
