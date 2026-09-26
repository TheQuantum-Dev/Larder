//
//  AppClock.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation

/// The current time, kept in one place so debug builds can pretend it's a
/// different time of day.
nonisolated enum AppClock {
    static var now: Date {
        #if DEBUG
        Date().addingTimeInterval(debugOffset)
        #else
        Date()
        #endif
    }

    #if DEBUG
    /// `-now 2026-09-26T08:30` (local time) makes the app act as if it were then,
    /// and the clock carries on from there (debug builds only).
    private static let debugOffset: TimeInterval = {
        guard let text = UserDefaults.standard.string(forKey: "now") else { return 0 }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date.timeIntervalSinceNow }
        }
        return 0
    }()
    #endif
}
