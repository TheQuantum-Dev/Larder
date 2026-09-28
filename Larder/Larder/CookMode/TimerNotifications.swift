//
//  TimerNotifications.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import Foundation
import UserNotifications

/// What the notification for a Cook Mode timer says, worked out separately
/// from sending it so it can be tested.
nonisolated struct TimerReminder: Equatable, Sendable {
    let id: String
    let title: String
    let body: String
    let seconds: TimeInterval

    /// The ring that plays with it, bundled as a plain file because a
    /// notification can't play a sound from the asset catalog.
    static let soundFile = "TimerAlarm.wav"

    static func id(recipeID: String, step: Int) -> String {
        "cook-timer-\(recipeID)-\(step)"
    }

    static func make(recipe: Recipe, step: Int, seconds: TimeInterval) -> TimerReminder {
        let text = recipe.steps.indices.contains(step) ? recipe.steps[step].text : ""
        return TimerReminder(id: id(recipeID: recipe.id, step: step),
                             title: "Step \(step + 1) is done",
                             body: "\(recipe.title): \(snippet(of: text))",
                             seconds: max(1, seconds))
    }

    /// The step's first sentence, cut short if it runs long.
    static func snippet(of text: String, limit: Int = 80) -> String {
        let first = text.split(separator: ".", maxSplits: 1).first.map(String.init) ?? text
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > limit else { return trimmed + "." }
        let cut = trimmed.prefix(limit)
        let word = cut.lastIndex(of: " ").map { cut[..<$0] } ?? cut
        return word + "…"
    }
}

/// Where a cook session sends its timer notifications. Tests use a fake.
protocol TimerNotifying: AnyObject {
    func schedule(_ reminder: TimerReminder)
    func cancel(id: String)
    func clearDelivered(id: String)
}

/// The real one, through the system's notification center. With no delegate
/// set, nothing shows while Larder is open, which is right: the alarm in the
/// app is already ringing.
final class TimerNotifications: TimerNotifying {
    static let shared = TimerNotifications()

    func schedule(_ reminder: TimerReminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = UNNotificationSound(named: UNNotificationSoundName(TimerReminder.soundFile))
        content.threadIdentifier = "cook-timers"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminder.seconds, repeats: false)
        let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    func clearDelivered(id: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }

    /// Whether the person has said yes, no, or hasn't been asked yet.
    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
