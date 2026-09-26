//
//  RecipesView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import SwiftData
import SwiftUI

/// Quick ways to narrow the list. One at a time, so it's always obvious why
/// something is or isn't showing.
nonisolated enum RecipeFilter: String, CaseIterable, Identifiable, Sendable {
    case all, favorites, ready, quick, cheap, noStove, highProtein, lighter, hearty

    var id: String { rawValue }

    /// The chips to offer. The calorie and protein ones go away entirely when
    /// someone has chosen not to see numbers.
    static func available(showsNutrition: Bool) -> [RecipeFilter] {
        showsNutrition ? allCases : allCases.filter { !$0.needsNutrition }
    }

    var needsNutrition: Bool { [.highProtein, .lighter, .hearty].contains(self) }

    var title: String {
        switch self {
        case .all: "All"
        case .favorites: "Favorites"
        case .ready: "Ready now"
        case .quick: "Quick"
        case .cheap: "Cheap"
        case .noStove: "No stove"
        case .highProtein: "High protein"
        case .lighter: "Lighter"
        case .hearty: "Hearty"
        }
    }

    /// Ready in 15 minutes or less.
    static let quickMinutes = 15
    /// About a dollar a serving or less.
    static let cheapPerServing = 1.0
    /// Grams of protein per serving for "high protein".
    static let highProteinGrams = 25.0
    /// Calories per serving for "lighter", and for "hearty".
    static let lighterKcal = 450.0
    static let heartyKcal = 650.0

    func includes(_ match: RecipeMatch, favorites: Set<String> = []) -> Bool {
        switch self {
        case .all: true
        case .favorites: favorites.contains(match.id)
        case .ready: match.isReady
        case .quick: match.recipe.minutes <= Self.quickMinutes
        case .cheap: match.recipe.costPerServing <= Self.cheapPerServing
        case .noStove: match.recipe.needsNoStove
        case .highProtein: match.recipe.nutrition.protein >= Self.highProteinGrams
        case .lighter: match.recipe.nutrition.kcal <= Self.lighterKcal
        case .hearty: match.recipe.nutrition.kcal >= Self.heartyKcal
        }
    }

    /// The filter plus a search on the title, keeping the matcher's order.
    static func apply(_ filter: RecipeFilter, query: String, favorites: Set<String> = [],
                      to matches: [RecipeMatch]) -> [RecipeMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return matches.filter { match in
            filter.includes(match, favorites: favorites)
                && (trimmed.isEmpty || match.recipe.title.localizedCaseInsensitiveContains(trimmed))
        }
    }
}

/// Every recipe that fits the person's diet, best matches first. The
/// onboarding results screen shows a shortlist; this is the whole book.
struct RecipesView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query private var pantry: [PantryItem]
    @Query private var listed: [ShoppingItem]
    @Query private var notes: [RecipeNote]

    @State private var filter = RecipesView.launchFilter
    @State private var query = RecipesView.launchQuery
    @State private var selected: RecipeMatch?

    /// `-recipesQuery fried` starts with that search typed in (debug builds only).
    private static var launchQuery: String {
        #if DEBUG
        UserDefaults.standard.string(forKey: "recipesQuery") ?? ""
        #else
        ""
        #endif
    }

    /// `-recipesFilter favorites` starts with that chip picked (debug builds only).
    private static var launchFilter: RecipeFilter {
        #if DEBUG
        UserDefaults.standard.string(forKey: "recipesFilter").flatMap(RecipeFilter.init(rawValue:)) ?? .all
        #else
        .all
        #endif
    }

    private var allMatches: [RecipeMatch] {
        RecipeMatcher.matches(pantry: Set(pantry.map(\.ingredientID)), diets: app.profile.dietSet,
                              priorities: app.profile.prioritySet, cooking: app.profile.cookingSet,
                              goal: app.profile.goalContext, taste: RecipeTaste(notes: notes), maxMissing: .max)
    }

    private var favorites: Set<String> {
        Set(notes.filter(\.isFavorite).map(\.recipeID))
    }

    var body: some View {
        let shown = RecipeFilter.apply(filter, query: query, favorites: favorites, to: allMatches)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    filterChips
                    if shown.isEmpty {
                        emptyState
                    } else {
                        section("Ready now", shown.filter(\.isReady))
                        section("One ingredient away", shown.filter { $0.missing.count == 1 })
                        section("Just a couple of things away", shown.filter { $0.missing.count == 2 })
                        section("Worth a shop", shown.filter { $0.missing.count > 2 })
                    }
                }
                .padding(Theme.Spacing.s)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Recipes")
            .searchable(text: $query, prompt: "Search recipes")
        }
        .recipeCookingFlow(selected: $selected, diets: app.profile.dietSet, showsNutrition: app.profile.showsNutrition,
                           offersShoppingList: true)
        .tapFeedback(filter)
        .task { openForDebug() }
    }

    /// `-openRecipe egg-fried-rice` opens that recipe's sheet on launch (debug builds only).
    private func openForDebug() {
        #if DEBUG
        guard let id = UserDefaults.standard.string(forKey: "openRecipe"), selected == nil,
              let match = allMatches.first(where: { $0.id == id }) else { return }
        selected = match
        #endif
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(RecipeFilter.available(showsNutrition: app.profile.showsNutrition)) { option in
                    Button { filter = option } label: {
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .padding(.horizontal, Theme.Spacing.s)
                            .frame(minHeight: 40)
                            .background(filter == option ? Theme.Palette.amber.opacity(0.35) : Theme.Palette.surface,
                                        in: Capsule())
                            .overlay {
                                Capsule().strokeBorder(filter == option ? Theme.Palette.amber : .clear, lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(filter == option ? .isSelected : [])
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: filter)
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [RecipeMatch]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                ForEach(items) { match in
                    let badges = RecipeBadges.reasons(for: match, priorities: app.profile.prioritySet,
                                                      cooking: app.profile.cookingSet, goal: app.profile.goalContext)
                    RecipeCard(match: match, badges: badges, showsNutrition: app.profile.showsNutrition,
                               isFavorite: favorites.contains(match.id),
                               listAction: RecipeListAction.nudge(for: match, listed: Set(listed.map(\.ingredientID)),
                                                                  context: context)) { selected = match }
                }
            }
        }
    }

    private var showsFavoritesHint: Bool { filter == .favorites && query.isEmpty }

    private var emptyTitle: String {
        if showsFavoritesHint { return "No favorites yet" }
        return query.isEmpty ? "Nothing fits that just yet" : "No recipes called \"\(query)\""
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.s) {
            NutmegView()
                .frame(height: 120)
            Text(emptyTitle)
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            if showsFavoritesHint {
                Text("Tap the heart on any recipe and it'll wait for you here.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
            Button("Show everything") {
                filter = .all
                query = ""
            }
            .buttonStyle(PillButtonStyle(fill: Theme.Palette.softAmber))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.l)
    }
}
