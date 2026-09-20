//
//  WelcomeView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// First screen: Nutmeg says hello and a small photo-to-recipe preview shows
/// what the app does, instead of a list of features.
struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: 0)

            NutmegView()
                .frame(height: 180)

            VStack(spacing: Theme.Spacing.xs) {
                Text("Hi, I'm Nutmeg!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Snap your shelf and I'll find a recipe you can make right now.")
                    .font(.body)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    .multilineTextAlignment(.center)
            }

            preview

            Spacer(minLength: 0)

            Button("Let's go", action: onContinue)
                .buttonStyle(PillButtonStyle())
        }
        .padding(Theme.Spacing.s)
    }

    private var preview: some View {
        HStack(spacing: Theme.Spacing.xs) {
            previewCard {
                Text("Your shelf").font(.caption.bold())
                Text("🥚 🍚\n🧅 🥫")
                    .font(.title)
                    .multilineTextAlignment(.center)
            }
            Image(systemName: "arrow.right")
                .font(.headline)
                .foregroundStyle(Theme.Palette.amber)
            previewCard {
                Text("Tonight").font(.caption.bold())
                Text("🍳").font(.title)
                Text("Egg fried rice").font(.subheadline.weight(.semibold))
                Text("15 min · about $2").font(.caption)
            }
        }
    }

    private func previewCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            content()
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}
