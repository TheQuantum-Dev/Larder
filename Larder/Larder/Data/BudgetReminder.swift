//
//  BudgetReminder.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import Foundation
import UserNotifications

/// A once-a-week nudge to glance at the budget, only for people who set one.
/// A real number isn't possible here — a scheduled notification's text is
/// fixed when it's set, long before it fires — so this just points at
/// Insights rather than guessing what it'll say by Sunday.
nonisolated enum BudgetReminder {
    static let identifier = "budget-reminder"
    /// Sunday, in `Calendar`'s weekday numbering (1 = Sunday).
    static let weekday = 1
    static let hour = 18
    static let title = "How did this week's food budget go?"
    static let body = "Take a look in Insights to see where you landed."

    enum Outcome: Equatable {
        /// Off, or no budget to check in on: clear anything pending.
        case cancel
        case schedule(weekday: Int, hour: Int, title: String, body: String)
    }

    static func outcome(weeklyBudgetIsSet: Bool, enabled: Bool) -> Outcome {
        guard enabled, weeklyBudgetIsSet else { return .cancel }
        return .schedule(weekday: weekday, hour: hour, title: title, body: body)
    }
}

/// The system repeats this on its own once it's set, so there's no
/// app-side rescheduling and nothing that can drift.
enum BudgetReminderScheduler {
    static func refresh(weeklyBudgetIsSet: Bool, enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        guard case .schedule(let weekday, let hour, let title, let body) =
                BudgetReminder.outcome(weeklyBudgetIsSet: weeklyBudgetIsSet, enabled: enabled) else {
            center.removePendingNotificationRequests(withIdentifiers: [BudgetReminder.identifier])
            return
        }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var when = DateComponents()
        when.weekday = weekday
        when.hour = hour
        when.minute = 0
        let request = UNNotificationRequest(identifier: BudgetReminder.identifier, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
        try? await center.add(request)
    }
}
