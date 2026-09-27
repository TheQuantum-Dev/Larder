//
//  NutmegChatView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import SwiftData
import SwiftUI

/// The Nutmeg tab. Chatting is part of Larder Plus; without it, this shows
/// what a conversation looks like and a way in, rather than a locked wall.
struct NutmegChatView: View {
    @Environment(PurchaseStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.isPlusActive {
                    NutmegChatScreen()
                } else {
                    NutmegChatIntro()
                }
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Nutmeg")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// What someone without Plus sees: a real-looking exchange, so it's clear
/// what they'd be getting.
struct NutmegChatIntro: View {
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                NutmegView()
                    .frame(height: 140)
                    .padding(.top, Theme.Spacing.s)

                VStack(spacing: Theme.Spacing.xs) {
                    Text("Ask me anything about your kitchen")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("I can see what's in your pantry, every recipe, and how your week's going.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
                .foregroundStyle(Theme.Palette.textPrimary)

                VStack(spacing: Theme.Spacing.xs) {
                    ChatBubble(text: "I want something warm but I only have 15 minutes", fromNutmeg: false)
                    ChatBubble(text: "You've got eggs, rice and frozen veg, so egg fried rice is ready right now. About $1.30 and 15 minutes. Want to start?",
                               fromNutmeg: true)
                    ChatBubble(text: "How much have I saved this week?", fromNutmeg: false)
                    ChatBubble(text: "About $38 compared with ordering out. Three meals from your own pantry!", fromNutmeg: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("An example conversation with Nutmeg")

                VStack(spacing: Theme.Spacing.xs) {
                    Button("See Larder Plus") { showPaywall = true }
                        .buttonStyle(PillButtonStyle())
                    Text("Chatting with Nutmeg is part of Larder Plus. Scanning and recipes stay free.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
                }
            }
            .padding(Theme.Spacing.s)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView { _ in showPaywall = false }
        }
    }
}

/// One message. Nutmeg's sit on the left in amber; yours on the right, with a
/// small mic when it was said out loud.
struct ChatBubble: View {
    let text: String
    let fromNutmeg: Bool
    var isVoice = false

    var body: some View {
        HStack {
            if !fromNutmeg { Spacer(minLength: Theme.Spacing.l) }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if isVoice {
                    Image(systemName: "waveform")
                        .font(.footnote.bold())
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
                        .accessibilityLabel("Voice message")
                }
                Text(text)
                    .font(.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .background(fromNutmeg ? Theme.Palette.amber.opacity(0.3) : Theme.Palette.surface,
                        in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .fixedSize(horizontal: false, vertical: true)
            if fromNutmeg { Spacer(minLength: Theme.Spacing.l) }
        }
    }
}

/// The chat itself, for Plus. Every message is answered from a fresh
/// snapshot of the kitchen, and recipe suggestions come back as cards that
/// open the normal recipe and Cook Mode flow.
struct NutmegChatScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(OnlineRecipes.self) private var online
    @Environment(\.modelContext) private var context
    @Query private var pantry: [PantryItem]
    @Query private var meals: [CookedMeal]
    @AppStorage(AppSettings.weeklyBudgetKey) private var weeklyBudget = 0
    @AppStorage(AppSettings.weeklyMealGoalKey) private var mealGoal = 0
    @AppStorage(AppSettings.onlineRecipesKey) private var onlineEnabled = false
    @AppStorage(AppSettings.onlineOnlyKey) private var onlineOnly = false
    @AppStorage(AppSettings.hiddenOnlineKey) private var hiddenOnline = ""
    @AppStorage(AppSettings.autoAddToShoppingKey) private var autoAddToShopping = true

    @State private var chat = ChatModel()
    @State private var draft = ""
    @State private var selected: RecipeMatch?
    @State private var fetchMessage: String?
    @FocusState private var typing: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.s) {
                        if chat.messages.isEmpty { welcome }
                        ForEach(chat.messages) { message in
                            MessageRow(message: message, isLatest: message.id == chat.messages.last?.id,
                                       showsNutrition: app.profile.showsNutrition, recipe: recipe(withID:),
                                       onOpen: open, onQuickReply: { send($0) },
                                       onStep: { chat.stepChange(in: message.id, line: $0, by: $1) },
                                       onConfirm: { confirmChange(in: message.id) },
                                       onDismiss: { chat.dismissChange(in: message.id) })
                                .id(message.id)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if chat.isThinking {
                            ThinkingRow()
                                .id("thinking")
                                .transition(.opacity)
                        }
                    }
                    .padding(Theme.Spacing.s)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: chat.messages)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: chat.isThinking)
                }
                // Scrolling or tapping the conversation puts the keyboard away, so
                // the tab bar is always a moment away.
                .scrollDismissesKeyboard(.immediately)
                .simultaneousGesture(TapGesture().onEnded { typing = false })
                .onChange(of: chat.messages.count) { scrollToEnd(proxy) }
                .onChange(of: chat.isThinking) { scrollToEnd(proxy) }
            }
            suggestionChips
            inputBar
        }
        .recipeCookingFlow(selected: $selected, diets: app.profile.dietSet, showsNutrition: app.profile.showsNutrition,
                           offersShoppingList: true)
        .tapFeedback(chat.messages.count)
        .onAppear { chat.showsNutrition = app.profile.showsNutrition }
        .task {
            await chat.prewarm()
            await askDebugQuestions()
        }
        .alert("Can't open that one", isPresented: Binding(get: { fetchMessage != nil },
                                                          set: { if !$0 { fetchMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fetchMessage ?? "")
        }
    }

    /// Everything Nutmeg can see right now, including any recipes found online.
    private func kitchen() -> KitchenSnapshot {
        KitchenSnapshot.capture(pantry: pantry, meals: meals, profile: app.profile, weeklyBudget: weeklyBudget,
                                mealGoal: mealGoal, online: online.recipes, onlineStatus: onlineAvailability,
                                onlineOnly: onlineEnabled && onlineOnly, hiddenOnline: RecipePool.hiddenIDs(hiddenOnline))
    }

    private var onlineAvailability: KitchenSnapshot.OnlineAvailability {
        guard OnlineRecipeConfig.isAvailable else { return .unavailable }
        guard onlineEnabled else { return .off }
        switch online.status {
        case .ready: return .ready
        case .loading, .idle: return .looking
        case .exhausted: return .resting
        case .offline, .failed: return .offline
        case .off: return .off
        case .unavailable: return .unavailable
        }
    }

    /// `-chatAsk "What can I make?|How's my streak?"` asks those on open, one
    /// after another (debug builds only).
    private func askDebugQuestions() async {
        #if DEBUG
        guard chat.messages.isEmpty, let list = UserDefaults.standard.string(forKey: "chatAsk") else { return }
        // Online recipes may still be on their way.
        if list.localizedCaseInsensitiveContains("online") { try? await Task.sleep(for: .seconds(3)) }
        for question in list.split(separator: "|").map(String.init) {
            await chat.send(question, kitchen: kitchen(), isVoice: question.hasPrefix("🎙"))
        }
        #endif
    }

    // MARK: - Pieces

    private var welcome: some View {
        VStack(spacing: Theme.Spacing.s) {
            NutmegView()
                .frame(height: 120)
            Text("What are we cooking?")
                .font(.title2.bold())
            Text(chat.engine == .model
                 ? "I can see your pantry, every recipe, and how your week's going. Ask me anything food-related, or tell me what to add to your pantry."
                 : "I can see your pantry, every recipe, and how your week's going. Tap a question below, ask your own, or tell me what to add to your pantry.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(.top, Theme.Spacing.l)
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(chat.suggestions, id: \.self) { suggestion in
                    Button(suggestion) { send(suggestion) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .padding(.horizontal, Theme.Spacing.s)
                        .frame(minHeight: 40)
                        .background(Theme.Palette.surface, in: Capsule())
                        .buttonStyle(.plain)
                        .disabled(chat.isThinking)
                }
            }
            .padding(.horizontal, Theme.Spacing.s)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
            if typing {
                Button { typing = false } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .frame(width: 44, height: 50)
                }
                .accessibilityLabel("Hide the keyboard")
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            TextField("Ask Nutmeg…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($typing)
                .submitLabel(.send)
                .onSubmit { send(draft) }
                // A field that grows to several lines takes Return as a new
                // line, so Return is caught here and sends instead.
                .onChange(of: draft) { _, text in
                    guard text.contains("\n") else { return }
                    draft = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                    send(draft)
                }
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.vertical, Theme.Spacing.xs)
                .frame(minHeight: 50)
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            Button { send(draft) } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.Palette.onAccent)
                    .frame(width: 50, height: 50)
                    .background(Theme.Palette.amber, in: Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || chat.isThinking)
            .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty || chat.isThinking ? 0.5 : 1)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.xs)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: typing)
    }

    // MARK: - Actions

    private func send(_ text: String, isVoice: Bool = false) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !chat.isThinking else { return }
        let kitchen = kitchen()
        draft = ""
        Task { await chat.send(text, kitchen: kitchen, isVoice: isVoice) }
    }

    /// Saves a confirmed pantry change. Anything all gone goes on the shopping
    /// list, the same as after cooking.
    private func confirmChange(in messageID: UUID) {
        chat.confirmChange(in: messageID) { update in
            let removed = PantryRepository.apply(update, in: context)
            ShoppingRepository.addRunOut(removed, enabled: autoAddToShopping, in: context)
        }
    }

    /// Larder's own recipes, or one found online that's still in memory.
    private func recipe(withID id: String) -> Recipe? {
        RecipeStore.recipe(withID: id) ?? online.recipes.first { $0.id == id }
    }

    /// Opens a suggested recipe, matched against the pantry as it is now. An
    /// online one that's been let go is fetched again first.
    private func open(_ recipeID: String) {
        if let recipe = recipe(withID: recipeID) {
            select(recipe)
            return
        }
        guard recipeID.hasPrefix(OnlineRecipeMapper.idPrefix), onlineEnabled else {
            fetchMessage = "Turn on online recipes in Settings to open this one."
            return
        }
        Task {
            if let recipe = await online.recipe(id: recipeID) {
                select(recipe)
            } else {
                fetchMessage = "That recipe lives online and can't be reached right now. Try again when you're connected."
            }
        }
    }

    private func select(_ recipe: Recipe) {
        selected = RecipeMatcher.matches(recipes: [recipe], pantry: Set(pantry.map(\.ingredientID)),
                                         diets: app.profile.dietSet, maxMissing: .max).first
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            if chat.isThinking {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = chat.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

/// One message, with Nutmeg's small avatar beside his, and anything that
/// came with it underneath: recipe cards, a pantry change to confirm, or
/// quick replies (only on the latest message, so old ones don't linger).
private struct MessageRow: View {
    let message: ChatMessage
    let isLatest: Bool
    let showsNutrition: Bool
    let recipe: (String) -> Recipe?
    let onOpen: (String) -> Void
    let onQuickReply: (String) -> Void
    let onStep: (String, Int) -> Void
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        if message.role == .person {
            ChatBubble(text: message.text, fromNutmeg: false, isVoice: message.isVoice)
        } else {
            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                NutmegView()
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ChatBubble(text: message.text, fromNutmeg: true)
                    ForEach(message.recipeIDs, id: \.self) { id in
                        if let recipe = recipe(id) {
                            ChatRecipeCard(title: recipe.title, emoji: recipe.emoji, imageURL: recipe.imageURL,
                                           detail: detail(for: recipe), isOnline: recipe.isOnline) { onOpen(id) }
                        } else if let ref = message.onlineRefs.first(where: { $0.id == id }) {
                            // Let go of since (online recipes are only kept a little
                            // while): the name and photo, fetched again on tap.
                            ChatRecipeCard(title: ref.title, emoji: ref.emoji, imageURL: ref.imageURL,
                                           detail: "Tap to open", isOnline: true) { onOpen(id) }
                        }
                    }
                    if let proposal = message.pantryChange {
                        PantryChangeCard(proposal: proposal, onStep: onStep, onConfirm: onConfirm, onDismiss: onDismiss)
                    }
                    if isLatest, !message.quickReplies.isEmpty {
                        FlowLayout(fillsWidth: true) {
                            ForEach(message.quickReplies, id: \.self) { reply in
                                Button(reply) { onQuickReply(reply) }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                    .padding(.horizontal, Theme.Spacing.s)
                                    .frame(minHeight: 40)
                                    .overlay { Capsule().strokeBorder(Theme.Palette.amber, lineWidth: 2) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
        }
    }

    private func detail(for recipe: Recipe) -> String {
        var parts = ["\(recipe.minutes) min", recipe.costText]
        if showsNutrition { parts.append(recipe.nutrition.summaryText) }
        return parts.joined(separator: " · ")
    }
}

private struct ChatRecipeCard: View {
    let title: String
    let emoji: String
    let imageURL: String?
    let detail: String
    let isOnline: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                RecipeThumb(emoji: emoji, imageURL: imageURL, size: 44, emojiSize: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    if isOnline { OnlineTag() }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.4))
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(Theme.Spacing.xs)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the recipe")
    }
}

/// A pantry change to confirm: one row per item with + and −, then a button
/// to do it and one to leave it. Afterwards it says what happened.
private struct PantryChangeCard: View {
    let proposal: PantryProposal
    let onStep: (String, Int) -> Void
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    private var isPending: Bool { proposal.state == .pending }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(proposal.lines) { line in
                HStack(spacing: Theme.Spacing.xs) {
                    Text(line.item.emoji)
                    Text(line.item.name)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(line.action == .remove && proposal.state == .applied)
                    Spacer(minLength: 0)
                    if isPending, line.hasStepper {
                        stepButton("minus", label: "Less \(line.item.name)") { onStep(line.id, -1) }
                            .disabled(line.quantity == nil || line.quantity == 0)
                    }
                    Text(line.label)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .frame(minWidth: 60)
                    if isPending, line.hasStepper {
                        stepButton("plus", label: "More \(line.item.name)") { onStep(line.id, 1) }
                    }
                }
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(minHeight: 44)
            }
            switch proposal.state {
            case .pending:
                Button(proposal.isAllAdds ? "Add to pantry" : "Update pantry", action: onConfirm)
                    .buttonStyle(PillButtonStyle())
                    .padding(.top, Theme.Spacing.xs)
                Button("Not now", action: onDismiss)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            case .applied:
                Label("Your pantry's updated", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.sage)
            case .dismissed:
                Text("Left as it was")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
            }
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .strokeBorder(Theme.Palette.amber, lineWidth: isPending ? 2 : 0)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: proposal)
        .tapFeedback(proposal.lines.map(\.quantity))
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.bold())
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 36, height: 36)
                .background(Theme.Palette.softAmber, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Nutmeg peeking while an answer is on its way.
private struct ThinkingRow: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            NutmegView(mood: .peeking)
                .frame(width: 40, height: 40)
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(0..<3) { dot in
                    Circle()
                        .fill(Theme.Palette.textPrimary.opacity(phase == dot ? 0.7 : 0.25))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, Theme.Spacing.s)
            .frame(minHeight: 40)
            .background(Theme.Palette.amber.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            Spacer()
        }
        .accessibilityLabel("Nutmeg is thinking")
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.easeInOut(duration: 0.2)) { phase = (phase + 1) % 3 }
            }
        }
    }
}
