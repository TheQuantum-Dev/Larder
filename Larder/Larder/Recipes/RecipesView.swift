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
    case all, favorites, online, ready, quick, cheap, noStove, highProtein, lighter, hearty

    var id: String { rawValue }

    /// The chips to offer. The calorie and protein ones go away entirely when
    /// someone has chosen not to see numbers, and "Online" only shows while
    /// online recipes are switched on.
    static func available(showsNutrition: Bool, offersOnline: Bool = false) -> [RecipeFilter] {
        allCases.filter { (showsNutrition || !$0.needsNutrition) && (offersOnline || $0 != .online) }
    }

    var needsNutrition: Bool { [.highProtein, .lighter, .hearty].contains(self) }

    var title: String {
        switch self {
        case .all: "All"
        case .favorites: "Favorites"
        case .online: "Online"
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
        case .online: match.recipe.isOnline
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
    @Environment(OnlineRecipes.self) private var online
    @Environment(\.modelContext) private var context
    @Query private var pantry: [PantryItem]
    @Query private var listed: [ShoppingItem]
    @Query private var notes: [RecipeNote]
    @AppStorage(AppSettings.onlineRecipesKey) private var onlineEnabled = false
    @AppStorage(AppSettings.onlineOnlyKey) private var onlineOnly = false
    @AppStorage(AppSettings.hiddenOnlineKey) private var hiddenOnline = ""

    @State private var filter = RecipesView.launchFilter
    @State private var query = RecipesView.launchQuery
    @State private var selected: RecipeMatch?
    /// The saved online recipe being fetched again, and why one couldn't be opened.
    @State private var fetchingID: String?
    @State private var fetchMessage: String?

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

    /// Larder's recipes and the online ones, ranked together. Favorites always
    /// include Larder's own, even with "only online recipes" on: they're yours.
    private var allMatches: [RecipeMatch] {
        let taste = RecipeTaste(notes: notes)
        return RecipePool.matches(bundled: RecipeStore.all, online: online.recipes,
                                  onlineOnly: showsOnlyOnline && filter != .favorites,
                                  hidden: RecipePool.hiddenIDs(hiddenOnline)) { recipes in
            RecipeMatcher.matches(recipes: recipes, pantry: Set(pantry.map(\.ingredientID)),
                                  diets: app.profile.dietSet, priorities: app.profile.prioritySet,
                                  cooking: app.profile.cookingSet, goal: app.profile.goalContext,
                                  taste: taste, maxMissing: .max)
        }
    }

    private var offersOnline: Bool { OnlineRecipeConfig.isAvailable && onlineEnabled }
    private var showsOnlyOnline: Bool { offersOnline && onlineOnly }

    private var favorites: Set<String> {
        Set(notes.filter(\.isFavorite).map(\.recipeID))
    }

    var body: some View {
        let shown = RecipeFilter.apply(filter, query: query, favorites: favorites, to: allMatches)
        let savedOnline = savedOnlineNotes(excluding: shown)
        let hasOnline = shown.contains(where: \.recipe.isOnline)
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    filterChips
                    // With only online recipes on, say why Larder's own are showing instead.
                    if showsOnlyOnline, filter != .favorites, !hasOnline { onlineStatusNote }
                    if filter == .online, !hasOnline {
                        if !showsOnlyOnline { onlineStatusNote }
                    } else if shown.isEmpty, savedOnline.isEmpty {
                        emptyState
                    } else {
                        section("Ready now", shown.filter(\.isReady))
                        section("One ingredient away", shown.filter { $0.missing.count == 1 })
                        section("Just a couple of things away", shown.filter { $0.missing.count == 2 })
                        section("Worth a shop", shown.filter { $0.missing.count > 2 })
                        savedOnlineSection(savedOnline)
                    }
                    onlineFooter(hasOnline: hasOnline)
                }
                .padding(Theme.Spacing.s)
            }
            .task { await scrollForDebug(proxy, to: shown.first(where: \.recipe.isOnline)?.id) }
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Recipes")
            .searchable(text: $query, prompt: "Search recipes")
        }
        .recipeCookingFlow(selected: $selected, diets: app.profile.dietSet, showsNutrition: app.profile.showsNutrition,
                           offersShoppingList: true)
        .tapFeedback(filter)
        .task { await openForDebug() }
        .alert("Can't open that one", isPresented: Binding(get: { fetchMessage != nil },
                                                          set: { if !$0 { fetchMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fetchMessage ?? "")
        }
    }

    /// `-recipesScroll online` scrolls to the first online recipe once they've had
    /// time to load (debug builds only).
    private func scrollForDebug(_ proxy: ScrollViewProxy, to id: String?) async {
        #if DEBUG
        guard UserDefaults.standard.string(forKey: "recipesScroll") == "online" else { return }
        // A real lookup can take a few seconds, so wait for it rather than scrolling to a gap.
        try? await Task.sleep(for: .seconds(8))
        let first = allMatches.first(where: \.recipe.isOnline)?.id ?? id
        if let first { withAnimation { proxy.scrollTo(first, anchor: .top) } }
        #endif
    }

    /// `-openRecipe egg-fried-rice` opens that recipe's sheet on launch, and `sp-900001` waits for
    /// the online recipes to load first (debug builds only).
    private func openForDebug() async {
        #if DEBUG
        guard let id = UserDefaults.standard.string(forKey: "openRecipe") else { return }
        for _ in 0..<20 {
            if selected == nil, let match = allMatches.first(where: { $0.id == id }) {
                selected = match
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        #endif
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(RecipeFilter.available(showsNutrition: app.profile.showsNutrition,
                                               offersOnline: offersOnline)) { option in
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
                ForEach(items) { match in card(for: match) }
            }
        }
    }

    private func card(for match: RecipeMatch) -> some View {
        let badges = RecipeBadges.reasons(for: match, priorities: app.profile.prioritySet,
                                          cooking: app.profile.cookingSet, goal: app.profile.goalContext)
        return RecipeCard(match: match, badges: badges, showsNutrition: app.profile.showsNutrition,
                          isFavorite: favorites.contains(match.id),
                          listAction: RecipeListAction.nudge(for: match, listed: Set(listed.map(\.ingredientID)),
                                                             context: context)) { selected = match }
            .id(match.id)
    }

    // MARK: - Online

    /// Nutmeg's line for whatever the online lookup is doing, so there's never a silent gap.
    private var onlineMessage: (text: String, busy: Bool) {
        switch online.status {
        case .loading:
            ("Looking for ideas online…", true)
        case .idle, .off, .unavailable:
            pantry.isEmpty ? ("Add a few things to your pantry and I'll look for ideas online.", false)
                           : ("Looking for ideas online…", true)
        case .ready:
            ("Nothing new online for this pantry yet. Add a few more things and I'll look again.", false)
        case .exhausted:
            ("Online ideas are resting for today. Larder's own recipes are all right here.", false)
        case .offline:
            ("You're offline, so it's just Larder's own recipes for now.", false)
        case .failed:
            ("I couldn't reach the online recipes just now. Larder's own recipes are right here.", false)
        }
    }

    private var onlineStatusNote: some View {
        OnlineNote(text: onlineMessage.text, showsProgress: onlineMessage.busy)
    }

    /// Under the list: the credit the online recipes need whenever one is
    /// showing, a note while they're still on their way, or, if online recipes
    /// are switched off, a friendly ask.
    @ViewBuilder
    private func onlineFooter(hasOnline: Bool) -> some View {
        let isPlainView = filter == .all && query.isEmpty
        if hasOnline {
            SpoonacularCredit()
        } else if OnlineRecipeConfig.isAvailable, isPlainView {
            if !onlineEnabled {
                OnlineOptInCard { onlineEnabled = true }
            } else if !showsOnlyOnline {
                onlineStatusNote
            }
        }
    }

    /// Favorites that came from online but aren't in memory any more (they
    /// aren't kept between sessions): a row that fetches it again when tapped.
    /// The ones still in memory are already in the list as full cards.
    private func savedOnlineNotes(excluding shown: [RecipeMatch]) -> [RecipeNote] {
        guard filter == .favorites else { return [] }
        let inMemory = Set(shown.map(\.id))
        return notes.filter { note in
            note.isFavorite && note.recipeID.hasPrefix(OnlineRecipeMapper.idPrefix) && !inMemory.contains(note.recipeID)
                && (query.isEmpty || note.title.localizedCaseInsensitiveContains(query))
        }
    }

    @ViewBuilder
    private func savedOnlineSection(_ saved: [RecipeNote]) -> some View {
        if !saved.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Saved from online")
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                ForEach(saved) { note in
                    SavedOnlineRow(note: note, isLoading: fetchingID == note.recipeID) { openSaved(note) }
                }
            }
        }
    }

    private func openSaved(_ note: RecipeNote) {
        guard onlineEnabled else {
            fetchMessage = "Turn on online recipes in Settings to open this one."
            return
        }
        fetchingID = note.recipeID
        Task {
            let recipe = await online.recipe(id: note.recipeID)
            fetchingID = nil
            guard let recipe,
                  let match = RecipeMatcher.matches(recipes: [recipe], pantry: Set(pantry.map(\.ingredientID)),
                                                    maxMissing: .max).first else {
                fetchMessage = "That recipe lives online and can't be reached right now. Try again when you're connected."
                return
            }
            selected = match
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
