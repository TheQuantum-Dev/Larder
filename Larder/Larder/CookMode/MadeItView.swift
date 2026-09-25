//
//  MadeItView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftUI

/// Everything the celebration needs to show.
struct MadeResult {
    let summary: MealSummary
    let isFirstMeal: Bool
    let stats: MealStats
}

/// The moment after a meal is marked as made. The first one ever is the big
/// one (confetti, a hopping Nutmeg, and the strongest haptic); later meals get
/// a smaller version. It also asks what ran out, instead of guessing.
struct MadeItView: View {
    let result: MadeResult
    /// Pantry ingredients this recipe used, which might have run out.
    let candidates: [ResolvedItem]
    @Binding var usedUp: Set<String>
    let onDone: (Set<String>) -> Void

    @AppStorage(AppSettings.weeklyMealGoalKey) private var mealGoal = 0
    @AppStorage(AppSettings.autoAddToShoppingKey) private var autoAddToShopping = true
    @State private var shownSaving = 0.0
    @State private var hapticTick = 0
    /// Held back until the first-meal haptic build-up peaks, so the confetti
    /// actually lands with it instead of firing the instant the screen appears.
    @State private var showConfetti = false

    private var summary: MealSummary { result.summary }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    NutmegView(mood: .celebrating, pose: .bothWave)
                        .frame(height: 160)
                        .padding(.top, Theme.Spacing.l)

                    VStack(spacing: Theme.Spacing.xs) {
                        if result.isFirstMeal {
                            Label("Your first meal!", systemImage: "star.fill")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.Palette.onAccent)
                                .padding(.horizontal, Theme.Spacing.s)
                                .frame(minHeight: 30)
                                .background(Theme.Palette.sage, in: Capsule())
                        }
                        Text(result.isFirstMeal ? "You did it!" : "Nice one!")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("You made \(summary.title.lowercased()).")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    }

                    savingsCard

                    // The question comes before the stats, so it isn't missed.
                    if !candidates.isEmpty { runOutSection }

                    statsRow
                }
                .padding(Theme.Spacing.s)
            }

            if showConfetti {
                ConfettiView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Done") { onDone(usedUp) }
                .buttonStyle(PillButtonStyle())
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.top, Theme.Spacing.xs)
                .background(Theme.Palette.background)
        }
        // Later meals get a firm thump. The first meal's build-up-then-pop
        // haptic is custom (see Haptics.firstMealCelebration), so this only
        // ever fires for the plain case.
        .sensoryFeedback(trigger: hapticTick) { _, _ in .impact(weight: .heavy) }
        .tapFeedback(usedUp)
        .onAppear {
            if result.isFirstMeal {
                Haptics.firstMealCelebration()
                SoundPlayer.firstMealCelebration()
                Task {
                    try? await Task.sleep(for: .seconds(Haptics.firstMealBuildUp))
                    withAnimation { showConfetti = true }
                }
            } else {
                hapticTick += 1
            }
            withAnimation(.easeOut(duration: 1.4)) {
                shownSaving = summary.saved
            }
        }
    }

    // MARK: - Pieces

    private var savingsCard: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("You saved about")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            Text(shownSaving, format: .currency(code: "USD"))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: shownSaving))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("You spent \(Money.about(summary.totalCost)). Ordering out would be \(Money.about(summary.orderOutTotal)).")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var statsRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            stat("Meals this week", Commitment.mealsThisWeekText(count: result.stats.mealsThisWeek, goal: mealGoal))
            stat("Saved so far", Money.text(result.stats.totalSaved))
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(title)
                .font(.footnote)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var runOutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Anything run out?")
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(autoAddToShopping
                 ? "Tap what you finished. I'll take it off your pantry and put it on your shopping list."
                 : "Tap what you finished and I'll take it off your pantry.")
                .font(.footnote)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            FlowLayout {
                ForEach(candidates) { item in
                    ItemChip(item: item, isChecked: usedUp.contains(item.id)) {
                        usedUp.formSymmetricDifference([item.id])
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
