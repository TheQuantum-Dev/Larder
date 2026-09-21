//
//  AllSetView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftUI

/// The last screen of onboarding. It replaces a sign-in step, since nothing in
/// the app needs an account, and it's warm whichever way the paywall went:
/// gratitude for a purchase, and no guilt at all for skipping it.
struct AllSetView: View {
    let outcome: PaywallView.Outcome
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: 0)

            NutmegView()
                .frame(height: 180)

            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }

            Spacer(minLength: 0)

            Button("Take me home", action: onFinish)
                .buttonStyle(PillButtonStyle())
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.background.ignoresSafeArea())
    }

    private var title: String {
        switch outcome {
        case .purchased: "Welcome to Larder Plus!"
        case .declined: "You're all set!"
        }
    }

    private var message: String {
        switch outcome {
        case .purchased:
            "Thank you, it really helps. Now let's get cooking."
        case .declined:
            "No pressure at all. Scanning and recipes are yours for free, and I'm here whenever you want more."
        }
    }
}
