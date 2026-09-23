//
//  NotificationPreScreen.swift
//  Larder
//
//  Created by Joshua Samuel on 9/22/26.
//

import SwiftUI
import UserNotifications

/// Nutmeg explains what notifications are actually for before the system
/// ever asks. Comes after the paywall, on purpose: it's not something to
/// get out of the way before the decision that matters, and either answer
/// here is fine — nothing about the app depends on it.
struct NotificationPreScreen: View {
    let onContinue: () -> Void

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: 0)

            NutmegView()
                .frame(height: 160)

            VStack(spacing: Theme.Spacing.xs) {
                Text("Want a nudge now and then?")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Just a few, and only when they're useful.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                reason("refrigerator", "When your pantry's running low")
                reason("calendar", "If it's been a few days since you've cooked")
                reason("dollarsign.circle", "A weekly check-in on your budget")
            }
            .padding(Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))

            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.xs) {
                Button("Turn on notifications") { respond(request: true) }
                    .buttonStyle(PillButtonStyle())
                    .disabled(isRequesting)
                Button("Not now") { respond(request: false) }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(minHeight: 44)
                    .disabled(isRequesting)
            }
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.background.ignoresSafeArea())
    }

    private func reason(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.Palette.amber)
                .frame(width: 30)
            Text(text)
                .font(.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "Not now" is respected as-is: asking the system anyway after someone
    /// declines would just be the prompt in disguise.
    private func respond(request: Bool) {
        guard request else {
            onContinue()
            return
        }
        isRequesting = true
        Task {
            await NotificationPermission.request()
            isRequesting = false
            onContinue()
        }
    }
}

/// The one place the system notification prompt is ever triggered from.
enum NotificationPermission {
    static func request() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }
}
