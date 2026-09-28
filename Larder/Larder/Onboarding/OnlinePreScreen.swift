//
//  OnlinePreScreen.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import SwiftUI

/// Nutmeg asks whether to look up extra recipes online. It comes right after
/// the first recipe, when the bundled ones have just shown what Larder does,
/// and either answer is fine: everything works without it, and it can be
/// changed any time in Settings. It's only asked in a build that can do it.
struct OnlinePreScreen: View {
    let onContinue: () -> Void

    @AppStorage(AppSettings.onlineRecipesKey) private var onlineRecipes = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            // At the biggest text sizes the page scrolls, with the buttons pinned
            // where they can always be reached.
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    heading
                    reasons
                }
                .padding(Theme.Spacing.s)
            }
            .safeAreaInset(edge: .bottom) {
                actions
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.top, Theme.Spacing.xs)
                    .background(Theme.Palette.background)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
        } else {
            VStack(spacing: Theme.Spacing.m) {
                Spacer(minLength: 0)
                heading
                reasons
                Spacer(minLength: 0)
                actions
            }
            .padding(Theme.Spacing.s)
            .background(Theme.Palette.background.ignoresSafeArea())
        }
    }

    private var heading: some View {
        VStack(spacing: Theme.Spacing.m) {
            NutmegView(mood: .peeking)
                .frame(height: 160)

            VStack(spacing: Theme.Spacing.xs) {
                Text("Want more recipe ideas?")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("It's optional. Turn it off anytime.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var reasons: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            reason("fork.knife", "Finds more recipes that fit your goal and what you have")
            reason("lock.fill", "Only ingredient names are sent, never photos")
            reason("switch.2", "Turn it off any time in Settings. Larder's own recipes are always here.")
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Button("Turn on") {
                onlineRecipes = true
                onContinue()
            }
            .buttonStyle(PillButtonStyle())
            Button("Not now", action: onContinue)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(minHeight: 44)
        }
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
}
