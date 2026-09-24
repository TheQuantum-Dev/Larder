//
//  PantryLowReminder.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import Foundation
import UserNotifications

/// A nudge for when the kitchen's nearly bare. Unlike the streak (which
/// naturally resets every day), "running low" can sit unchanged for a week,
/// so this remembers the last time it reminded and waits out a cooldown —
/// otherwise reopening the app the same morning a reminder is due would keep
/// pushing it a day later, forever, and it would never actually arrive.
nonisolated enum PantryLowReminder {
    static let identifier = "pantry-low-reminder"
    static let lowThreshold = 3
    static let cooldownDays = 3
    /// Late morning: after a look in the fridge, before the day's plans are set.
    static let hour = 10

    enum Outcome: Equatable {
        /// Plenty in the kitchen; cancel anything pending.
        case notLow
        /// Still low, but reminded recently — leave the pending one alone.
        case alreadyReminded
        /// Worth a nudge, scheduled for tomorrow morning.
        case remind(Plan)
    }

    struct Plan: Equatable {
        let fireDate: Date
        let title: String
        let body: String
    }

    static func outcome(pantryCount: Int, lastReminded: Date?, now: Date = Date(),
                        calendar: Calendar = .current) -> Outcome {
        guard pantryCount <= lowThreshold else { return .notLow }
        if let lastReminded {
            let today = calendar.startOfDay(for: now)
            let lastDay = calendar.startOfDay(for: lastReminded)
            let daysSince = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if daysSince < cooldownDays { return .alreadyReminded }
        }
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow) else {
            return .alreadyReminded
        }
        let title = pantryCount == 0 ? "Your pantry's empty" : "Your pantry's running low"
        let body = pantryCount == 0
            ? "Nothing to cook from right now. A quick scan and you're set."
            : "Only \(pantryCount) \(pantryCount == 1 ? "thing" : "things") left. Want to add a few groceries?"
        return .remind(Plan(fireDate: fireDate, title: title, body: body))
    }
}

/// Schedules or clears the pantry-low nudge, and remembers when it last did,
/// so the cooldown in `PantryLowReminder.outcome` actually holds.
enum PantryLowReminderScheduler {
    static func refresh(pantryCount: Int, enabled: Bool, now: Date = Date(),
                        defaults: UserDefaults = .standard) async {
        let center = UNUserNotificationCenter.current()
        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: [PantryLowReminder.identifier])
            return
        }
        let lastReminded = defaults.object(forKey: AppSettings.lastPantryReminderKey) as? Date
        switch PantryLowReminder.outcome(pantryCount: pantryCount, lastReminded: lastReminded, now: now) {
        case .notLow:
            center.removePendingNotificationRequests(withIdentifiers: [PantryLowReminder.identifier])
        case .alreadyReminded:
            break
        case .remind(let plan):
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            let when = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
            let request = UNNotificationRequest(identifier: PantryLowReminder.identifier, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false))
            try? await center.add(request)
            defaults.set(now, forKey: AppSettings.lastPantryReminderKey)
        }
    }
}
