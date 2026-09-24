//
//  StreakReminder.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import Foundation
import UserNotifications

/// The one evening nudge that keeps a cooking streak alive. At most one is
/// ever waiting, it only goes out when there's a streak to keep, and it's
/// written in Nutmeg's voice: a nudge, never a scolding.
nonisolated enum StreakReminder {
    static let identifier = "streak-reminder"
    /// 7pm: late enough that the day's plans are clear, early enough to cook.
    static let hour = 19

    struct Plan: Equatable {
        let fireDate: Date
        let title: String
        let body: String
    }

    static func plan(mealDates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Plan? {
        let today = calendar.startOfDay(for: now)
        switch CookingStreak.status(from: mealDates, now: now, calendar: calendar) {
        case .none:
            return nil
        case .atRisk(let days):
            // Tonight, if tonight's still ahead.
            guard let evening = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today),
                  evening > now else { return nil }
            return Plan(fireDate: evening,
                        title: "Your \(days)-day streak ends at midnight",
                        body: "Anything counts, even toast. Want me to find something quick?")
        case .safe(let days):
            // Already cooked today, so the next one to keep is tomorrow's.
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
                  let evening = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow) else { return nil }
            return Plan(fireDate: evening,
                        title: "Day \(days + 1) is up for grabs",
                        body: "Keep your streak going. Anything counts, even toast.")
        }
    }
}

/// Puts the planned reminder in the system's hands, replacing any older one.
/// Quietly does nothing if reminders are off or notifications weren't allowed.
enum StreakReminderScheduler {
    static func refresh(mealDates: [Date], enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [StreakReminder.identifier])
        guard enabled, let plan = StreakReminder.plan(mealDates: mealDates) else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default
        let when = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
        let request = UNNotificationRequest(identifier: StreakReminder.identifier, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false))
        try? await center.add(request)
    }
}
