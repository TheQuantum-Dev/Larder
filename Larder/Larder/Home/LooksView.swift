//
//  LooksView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import SwiftData
import SwiftUI
import UIKit

/// Choosing how Nutmeg looks, and with it the app icon. Coral is earned by
/// cooking; Snow and Harvest come with Larder Plus.
struct LooksView: View {
    @Environment(PurchaseStore.self) private var store
    @Query private var meals: [CookedMeal]
    @AppStorage(AppSettings.nutmegLookKey) private var lookName = NutmegLook.amber.rawValue
    @AppStorage(AppSettings.matchAppIconKey) private var matchIcon = true
    @State private var showPaywall = false

    private var selected: NutmegLook { NutmegLook(rawValue: lookName) ?? .amber }

    private var earned: Set<NutmegLook> {
        NutmegLook.earned(bestStreak: CookingStreak.best(from: meals.map(\.cookedAt)), mealCount: meals.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.s) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.xs),
                                    GridItem(.flexible(), spacing: Theme.Spacing.xs)],
                          spacing: Theme.Spacing.xs) {
                    ForEach(NutmegLook.allCases) { look in
                        tile(look)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Toggle("Match the app icon", isOn: $matchIcon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("Your home screen icon changes to fit his look. iOS asks you to confirm each change.")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
                .padding(Theme.Spacing.s)
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            }
            .padding(Theme.Spacing.s)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle("Nutmeg's look")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.Palette.amber)
        .tapFeedback(lookName)
        .onChange(of: matchIcon) { _, on in
            if on { applyIcon(for: selected) }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView { _ in showPaywall = false }
        }
    }

    // MARK: - Tiles

    private func tile(_ look: NutmegLook) -> some View {
        let isAvailable = look.isAvailable(earned: earned, hasPlus: store.isPlusActive)
        let isSelected = selected == look && isAvailable
        return Button { choose(look, isAvailable: isAvailable) } label: {
            VStack(spacing: Theme.Spacing.xs) {
                NutmegView(skin: look.skin)
                    .frame(height: 100)
                    .opacity(isAvailable ? 1 : 0.45)
                Text(look.title)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                status(look, isAvailable: isAvailable, isSelected: isSelected)
            }
            .padding(Theme.Spacing.s)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Theme.Palette.amber.opacity(0.25) : Theme.Palette.surface,
                        in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(isSelected ? Theme.Palette.amber : .clear, lineWidth: 3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func status(_ look: NutmegLook, isAvailable: Bool, isSelected: Bool) -> some View {
        Group {
            if isSelected {
                Label("Wearing now", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Palette.textPrimary)
            } else if isAvailable {
                Text(look.blurb)
            } else if look.isPlus {
                Label("Larder Plus", systemImage: "lock.fill")
            } else {
                Label(look.unlockHint ?? "Locked", systemImage: "lock.fill")
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
        .multilineTextAlignment(.center)
        .frame(minHeight: 40, alignment: .top)
    }

    // MARK: - Actions

    private func choose(_ look: NutmegLook, isAvailable: Bool) {
        if isAvailable {
            lookName = look.rawValue
            applyIcon(for: look)
        } else if look.isPlus {
            showPaywall = true
        }
    }

    private func applyIcon(for look: NutmegLook) {
        guard matchIcon else { return }
        let name = look.iconName
        let application = UIApplication.shared
        guard application.supportsAlternateIcons, application.alternateIconName != name else { return }
        application.setAlternateIconName(name) { _ in }
    }
}
