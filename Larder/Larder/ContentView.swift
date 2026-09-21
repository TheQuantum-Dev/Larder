//
//  ContentView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// Placeholder home screen until the real flow is built. It shows whether Plus
/// is active and presents the paywall.
struct ContentView: View {
    @Environment(PurchaseStore.self) private var store
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showPaywall = Self.launchedWithPaywall

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            NutmegView()
                .frame(height: 200)
            Text(store.isPlusActive ? "Larder Plus is active" : "Nutmeg is ready when you are")
                .font(.title3.bold())
                .foregroundStyle(Theme.Palette.textPrimary)
            Button("See Larder Plus") { showPaywall = true }
                .buttonStyle(PillButtonStyle())
            // Handy while the app is still being built; this moves to Settings.
            Button("Replay the intro") { hasCompletedOnboarding = false }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                .frame(minHeight: 44)
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView { _ in showPaywall = false }
        }
    }

    /// Lets a debug build open straight onto the paywall (`-showPaywall`).
    private static var launchedWithPaywall: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-showPaywall")
        #else
        false
        #endif
    }
}

#Preview {
    ContentView()
        .environment(PurchaseStore())
}
