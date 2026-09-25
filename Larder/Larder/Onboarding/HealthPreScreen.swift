//
//  HealthPreScreen.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import SwiftUI

/// Nutmeg explains what Apple Health is for before the system ever asks. It
/// comes right after the first recipe, when the calories and macros on it have
/// just shown why this might be useful, and either answer is fine: nothing in
/// the app depends on it.
struct HealthPreScreen: View {
    let onContinue: () -> Void

    @AppStorage(AppSettings.healthSyncKey) private var healthSync = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var isRequesting = false

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
            NutmegView()
                .frame(height: 160)

            VStack(spacing: Theme.Spacing.xs) {
                Text("Add your meals to Apple Health?")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Optional, and you stay in control.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var reasons: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            reason("fork.knife", "Saves the calories and macros of each meal you cook")
            reason("figure.stand", "Reads your height, weight and age to size your daily target")
            reason("lock.fill", "Stays on your phone. Change it any time in Health or Settings.")
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Button("Connect Apple Health") { respond(connect: true) }
                .buttonStyle(PillButtonStyle())
                .disabled(isRequesting)
            Button("Not now") { respond(connect: false) }
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(minHeight: 44)
                .disabled(isRequesting)
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

    /// "Not now" makes no system call at all; asking anyway after someone
    /// declines would just be the prompt in disguise.
    private func respond(connect: Bool) {
        guard connect else {
            onContinue()
            return
        }
        isRequesting = true
        Task {
            await Health.shared.requestAccess()
            healthSync = true
            var profile = ProfileStore.load()
            profile.merge(await Health.shared.readBodyStats(), overwrite: false)
            ProfileStore.save(profile)
            isRequesting = false
            onContinue()
        }
    }
}
