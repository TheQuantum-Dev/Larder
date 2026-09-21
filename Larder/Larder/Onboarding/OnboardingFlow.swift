//
//  OnboardingFlow.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// Runs the onboarding screens in order. The progress bar lives here, above
/// the screens, so it stays put and springs to its new width as you move on.
struct OnboardingFlow: View {
    let onFinish: () -> Void

    @State private var step = Self.startingStep
    @State private var answers = Self.startingAnswers
    @State private var goingBack = false

    var body: some View {
        VStack(spacing: 0) {
            if step.showsProgress {
                header
            }
            ZStack {
                content
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .opacity),
                        removal: .move(edge: goingBack ? .trailing : .leading).combined(with: .opacity)))
            }
        }
        .background(Theme.Palette.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Back")
            ProgressBar(progress: step.progress)
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.top, Theme.Spacing.xs)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            WelcomeView(onContinue: advance)
        case .diet:
            QuizScreen(title: "Anything I should cook around?",
                       subtitle: "Pick all that apply.",
                       selection: Bindable(answers).diets,
                       onContinue: advance)
        case .cooking:
            QuizScreen(title: "How's your cooking these days?",
                       subtitle: "No wrong answers. I'll match the recipes.",
                       selection: Bindable(answers).cooking,
                       onContinue: advance)
        case .priorities:
            QuizScreen(title: "What matters most this semester?",
                       subtitle: "Pick as many as you like.",
                       selection: Bindable(answers).priorities,
                       onContinue: advance)
        case .synthesis:
            SynthesisView(answers: answers, onContinue: advance)
        case .tryIt:
            TryItView { items in
                answers.pantry = items
                advance()
            }
        case .recipes:
            RecipeResultsView(matches: recipeResults.matches,
                              stretched: recipeResults.stretched,
                              diets: answers.diets.items,
                              onCook: { recipe in
                                  answers.firstRecipeID = recipe.id
                                  advance()
                              },
                              onAddMore: back)
        }
    }

    /// Recipes ranked for what the person confirmed, their diet and priorities.
    /// Recipes for what the person confirmed, widening the search if nothing is
    /// close, so this screen is never empty.
    private var recipeResults: (matches: [RecipeMatch], stretched: Bool) {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "recipesEmpty") { return ([], false) }
        #endif
        return RecipeMatcher.bestMatches(pantry: Set(answers.pantry.map(\.id)),
                                         diets: answers.diets.items,
                                         priorities: answers.priorities.items)
    }

    // MARK: - Navigation

    private func advance() {
        guard let next = step.next else {
            onFinish()
            return
        }
        move(to: next, back: false)
    }

    private func back() {
        guard let previous = step.previous else { return }
        move(to: previous, back: true)
    }

    /// The direction is set a moment before the step changes, so the screen
    /// that's leaving slides the right way too.
    private func move(to newStep: OnboardingStep, back: Bool) {
        goingBack = back
        Task { @MainActor in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                step = newStep
            }
        }
    }

    // MARK: - Debug launch options

    /// `-onboardingStep diet` opens straight onto a screen (debug builds only).
    private static var startingStep: OnboardingStep {
        #if DEBUG
        if let name = UserDefaults.standard.string(forKey: "onboardingStep"),
           let match = OnboardingStep.allCases.first(where: { "\($0)" == name }) {
            return match
        }
        #endif
        return .welcome
    }

    /// `-onboardingSample YES` pre-fills some answers, and `-onboardingPantry egg,rice`
    /// sets the pantry by ingredient id (debug builds only).
    private static var startingAnswers: OnboardingAnswers {
        let answers = OnboardingAnswers()
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "onboardingSample") {
            answers.diets.toggle(.vegetarian)
            answers.diets.toggle(.glutenFree)
            answers.cooking.toggle(.followRecipe)
            answers.priorities.toggle(.saveMoney)
            answers.priorities.toggle(.fast)
        }
        if let ids = UserDefaults.standard.string(forKey: "onboardingPantry") {
            answers.pantry = ids.split(separator: ",")
                .compactMap { IngredientCatalog.ingredient(withID: String($0)) }
                .map(ResolvedItem.init)
        }
        #endif
        return answers
    }
}
