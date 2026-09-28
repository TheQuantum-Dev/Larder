//
//  TimerAlertViews.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import SwiftUI
import UserNotifications

/// Pinned under Cook Mode's top bar while a timer rings, whatever step or
/// screen you're on, so Stop is always one tap away.
struct RingingBar: View {
    let session: CookSession

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wiggle = false

    private var title: String {
        let steps = session.ringing.sorted().map { "\($0 + 1)" }
        return steps.count == 1 ? "Step \(steps[0]) is done" : "Steps \(steps.joined(separator: " and ")) are done"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "bell.and.waves.left.and.right.fill")
                .font(.title2)
                .foregroundStyle(Theme.Palette.onAccent)
                .rotationEffect(.degrees(wiggle ? 12 : -12))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18).repeatForever(), value: wiggle)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Stop") { session.stopAllRinging() }
                .font(.headline)
                .foregroundStyle(Theme.Palette.onAccent)
                .padding(.horizontal, Theme.Spacing.s)
                .frame(minHeight: 44)
                .background(Theme.Palette.softAmber, in: Capsule())
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.Palette.amber, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .onAppear { wiggle = true }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Nutmeg asking, once, whether a timer may ping you when you've left the
/// app. The system prompt only appears if they say yes here.
struct TimerNotificationAsk: View {
    let onDone: (Bool) -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            NutmegView(pose: .rightWave)
                .frame(height: 100)
            Text("Want a ping when it's done?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("If you leave Larder while something's cooking, I'll ring your phone when the timer's up.")
                .font(.body)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Button("Yes, ping me") {
                Task {
                    let allowed = (try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound])) ?? false
                    onDone(allowed)
                }
            }
            .buttonStyle(PillButtonStyle())
            Button("Not now") { onDone(false) }
                .font(.body.weight(.semibold))
                .frame(minHeight: 44)
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(Theme.Spacing.s)
        .padding(.top, Theme.Spacing.s)
        .background(Theme.Palette.background.ignoresSafeArea())
    }
}
