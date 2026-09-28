//
//  CookAlarms.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import ActivityKit
import AlarmKit
import SwiftUI

/// Where a Cook Mode timer's alarm lives while it's out of the app's hands.
/// Tests use a fake.
protocol CookAlarming: AnyObject {
    /// True once the person has let Larder set alarms.
    var isAuthorized: Bool { get }
    func start(id: UUID, recipe: Recipe, step: Int, seconds: TimeInterval)
    func pause(id: UUID)
    func resume(id: UUID)
    func cancel(id: UUID)
}

/// What the system says an alarm is doing right now.
nonisolated enum CookAlarmState: Equatable, Sendable {
    case counting, paused, ringing
}

/// Cook Mode timers as real system alarms, through AlarmKit: the same thing
/// the Clock app's timers use. They ring on a locked phone and on silent,
/// and count down on the lock screen as a Live Activity (the LarderTimers
/// extension draws it).
final class CookAlarms: CookAlarming {
    static let shared = CookAlarms()

    private var manager: AlarmManager { .shared }

    var isAuthorized: Bool { manager.authorizationState == .authorized }
    var needsAsking: Bool { manager.authorizationState == .notDetermined }

    /// Shows the system prompt. Returns whether alarms are now allowed.
    func requestAuthorization() async -> Bool {
        (try? await manager.requestAuthorization()) == .authorized
    }

    func start(id: UUID, recipe: Recipe, step: Int, seconds: TimeInterval) {
        let reminder = TimerReminder.make(recipe: recipe, step: step, seconds: seconds)
        let presentation = AlarmPresentation(
            alert: .init(title: LocalizedStringResource(stringLiteral: reminder.title)),
            countdown: .init(title: LocalizedStringResource(stringLiteral: recipe.title)),
            paused: .init(title: "Paused",
                          resumeButton: AlarmButton(text: "Resume", textColor: .white, systemImageName: "play.fill")))
        let text = recipe.steps.indices.contains(step) ? recipe.steps[step].text : ""
        let metadata = CookTimerMetadata(recipeTitle: recipe.title, recipeEmoji: recipe.emoji, step: step + 1,
                                         stepSnippet: TimerReminder.snippet(of: text, limit: 60))
        let attributes = AlarmAttributes(presentation: presentation, metadata: metadata, tintColor: Self.tint)
        let configuration = AlarmManager.AlarmConfiguration<CookTimerMetadata>.timer(
            duration: reminder.seconds, attributes: attributes, sound: .named(TimerReminder.soundFile))
        Task {
            _ = try? await manager.schedule(id: id, configuration: configuration)
        }
    }

    func pause(id: UUID) { try? manager.pause(id: id) }
    func resume(id: UUID) { try? manager.resume(id: id) }

    /// Cancels a countdown, or silences one that's ringing.
    func cancel(id: UUID) {
        try? manager.stop(id: id)
        try? manager.cancel(id: id)
    }

    /// Every change to Larder's alarms, as each one's state. An alarm that's
    /// missing has been stopped or cancelled, from the app or the lock screen.
    func updates() -> AsyncStream<[UUID: CookAlarmState]> {
        let manager = manager
        return AsyncStream { continuation in
            let task = Task {
                for await alarms in manager.alarmUpdates {
                    var states: [UUID: CookAlarmState] = [:]
                    for alarm in alarms {
                        switch alarm.state {
                        case .alerting: states[alarm.id] = .ringing
                        case .paused: states[alarm.id] = .paused
                        default: states[alarm.id] = .counting
                        }
                    }
                    continuation.yield(states)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The look's main color, as a plain color the lock screen can keep.
    private static var tint: Color {
        let hex = ThemeStore.shared.theme.accentHex
        return Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                     blue: Double(hex & 0xFF) / 255)
    }
}
