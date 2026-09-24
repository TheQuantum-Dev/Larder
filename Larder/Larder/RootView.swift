//
//  RootView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// Shows onboarding until it's finished, then home.
struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        #if DEBUG
        // `-scanPreview yes` (or `empty`) opens the scan confirm screen with sample
        // results; `-scanPreviewQuery onion` also fills the search box.
        // `-cookRecipe egg-fried-rice` opens Cook Mode; add `-cookPhase gather|done|<step number>`
        // to start elsewhere, and `-cookTimer YES` to start the step's timer.
        if let id = UserDefaults.standard.string(forKey: "cookRecipe"), let recipe = RecipeStore.recipe(withID: id) {
            CookModeView(recipe: recipe, diets: [], startAt: Self.debugCookPhase, onFinish: {}, onClose: {})
        } else if let mode = UserDefaults.standard.string(forKey: "scanPreview") {
            ScanConfirmView(review: .sample(empty: mode == "empty"),
                            initialQuery: UserDefaults.standard.string(forKey: "scanPreviewQuery") ?? "") {}
        } else {
            flow
        }
        #else
        flow
        #endif
    }

    #if DEBUG
    private static var debugCookPhase: CookSession.Phase {
        switch UserDefaults.standard.string(forKey: "cookPhase") {
        case nil, "gather": .gather
        case "done": .done
        case "made": .made
        case let number?: .step(max(0, (Int(number) ?? 1) - 1))
        }
    }
    #endif

    private var flow: some View {
        ZStack {
            if hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlow { hasCompletedOnboarding = true }
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.9), value: hasCompletedOnboarding)
    }
}
