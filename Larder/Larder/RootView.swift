//
//  RootView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// Shows onboarding until it's finished, then the home screen.
struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        #if DEBUG
        // `-scanPreview yes` (or `empty`) opens the scan confirm screen with sample
        // results; `-scanPreviewQuery onion` also fills the search box.
        if let mode = UserDefaults.standard.string(forKey: "scanPreview") {
            ScanConfirmView(review: .sample(empty: mode == "empty"),
                            initialQuery: UserDefaults.standard.string(forKey: "scanPreviewQuery") ?? "") {}
        } else {
            flow
        }
        #else
        flow
        #endif
    }

    private var flow: some View {
        ZStack {
            if hasCompletedOnboarding {
                ContentView()
                    .transition(.opacity)
            } else {
                OnboardingFlow { hasCompletedOnboarding = true }
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.9), value: hasCompletedOnboarding)
    }
}
