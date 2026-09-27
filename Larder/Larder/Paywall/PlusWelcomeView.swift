//
//  PlusWelcomeView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import SwiftUI

/// Right after someone joins Larder Plus (in onboarding or later): a real
/// celebration. A swell and a chord, confetti, Nutmeg cheering while trying on
/// the new looks, and what's now theirs, one card at a time. It's a thank-you,
/// not a sales pitch: nothing here asks for anything else.
struct PlusWelcomeView: View {
    /// A restore welcomes someone back rather than as new.
    var isRestore = false
    let onDone: () -> Void

    /// There when this is shown inside the app, so "Say hi" can open the chat;
    /// missing during onboarding, where there are no tabs yet.
    @Environment(AppModel.self) private var app: AppModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = 0
    @State private var showConfetti = false
    @State private var lookIndex = 0
    @State private var cheer = 0
    @State private var sparkle = 0

    private static let looks: [NutmegSkin] = [.amber, .snow, .harvest]

    private struct Perk: Identifiable {
        let id: Int
        let symbol: String
        let title: String
        let detail: String
    }

    private let perks = [
        Perk(id: 0, symbol: "bubble.left.and.bubble.right.fill", title: "Chat with Nutmeg",
             detail: "Ask what to cook, check today's meals, or tell me what to add to your pantry. Out loud, too."),
        Perk(id: 1, symbol: "chart.bar.fill", title: "Nutrition and budget insights",
             detail: "Your week's calories, macros and spending, all in one place."),
        Perk(id: 2, symbol: "sparkles", title: "Seasonal looks and app icons",
             detail: "Dress me up for snow or harvest, with a matching icon. Find them in Settings."),
    ]

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()
            RadialGradient(colors: [Theme.Palette.amber.opacity(0.35), .clear], center: .top,
                           startRadius: 20, endRadius: 420)
                .ignoresSafeArea()
                .opacity(shown > 0 ? 1 : 0)

            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    ZStack {
                        SparkleBurst(trigger: sparkle)
                        NutmegView(mood: .celebrating, pose: .bothWave, skin: Self.looks[lookIndex], cheer: cheer)
                            .frame(height: 190)
                            .id(lookIndex)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                    .frame(height: 210)
                    .padding(.top, Theme.Spacing.m)

                    VStack(spacing: Theme.Spacing.xs) {
                        Text(isRestore ? "Welcome back to Larder Plus!" : "Welcome to Larder Plus!")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("Thank you. It really does help a student-built app keep cooking.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    }
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .opacity(shown > 0 ? 1 : 0)
                    .offset(y: shown > 0 ? 0 : 20)

                    VStack(spacing: Theme.Spacing.xs) {
                        ForEach(perks) { perk in
                            perkCard(perk)
                                .opacity(shown > perk.id + 1 ? 1 : 0)
                                .offset(y: shown > perk.id + 1 ? 0 : 30)
                        }
                    }
                }
                .padding(Theme.Spacing.s)
            }
            .safeAreaInset(edge: .bottom) { actions }

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .task { await celebrate() }
    }

    private func perkCard(_ perk: Perk) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            Image(systemName: perk.symbol)
                .font(.title3)
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(width: 50, height: 50)
                .background(Theme.Palette.amber, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(perk.title)
                    .font(.headline)
                Text(perk.detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if let app {
                Button("Say hi to Nutmeg") {
                    app.tab = .nutmeg
                    onDone()
                }
                .buttonStyle(PillButtonStyle())
                Button("Let's go", action: onDone)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(minHeight: 44)
            } else {
                Button("Let's go", action: onDone)
                    .buttonStyle(PillButtonStyle())
            }
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.top, Theme.Spacing.xs)
        .background(Theme.Palette.background)
        .opacity(shown > perks.count ? 1 : 0)
    }

    /// The sequence: a swell and a chord with the confetti, the words, the
    /// perks one by one, then Nutmeg trying on each look.
    private func celebrate() async {
        Haptics.firstMealCelebration()
        SoundPlayer.plusWelcome()
        if reduceMotion {
            shown = perks.count + 1
            return
        }
        try? await Task.sleep(for: .seconds(Haptics.firstMealBuildUp))
        withAnimation { showConfetti = true }
        cheer += 1
        for step in 1...(perks.count + 1) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) { shown = step }
            try? await Task.sleep(for: .milliseconds(260))
        }
        // Then he tries on the looks that come with Plus, round and round.
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                lookIndex = (lookIndex + 1) % Self.looks.count
            }
            sparkle += 1
        }
    }
}

/// A ring of little stars that bursts out and fades, each time `trigger` changes.
private struct SparkleBurst: View {
    let trigger: Int
    @State private var burst = false

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) / 8 * 2 * .pi
                Image(systemName: "sparkle")
                    .font(.system(size: index.isMultiple(of: 2) ? 18 : 12))
                    .foregroundStyle(Theme.Palette.amber)
                    .offset(x: cos(angle) * (burst ? 120 : 40), y: sin(angle) * (burst ? 100 : 30))
                    .opacity(burst ? 0 : 1)
                    .scaleEffect(burst ? 1.2 : 0.4)
            }
        }
        .opacity(trigger == 0 ? 0 : 1)
        .onChange(of: trigger) { _, _ in
            burst = false
            withAnimation(.easeOut(duration: 0.7)) { burst = true }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    PlusWelcomeView {}
}
