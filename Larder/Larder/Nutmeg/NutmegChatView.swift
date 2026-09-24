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

/// One message. Nutmeg's sit on the left in amber; yours on the right.
struct ChatBubble: View {
    let text: String
    let fromNutmeg: Bool

    var body: some View {
        HStack {
            if !fromNutmeg { Spacer(minLength: Theme.Spacing.l) }
            Text(text)
                .font(.body)
                .foregroundStyle(Theme.Palette.textPrimary)
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
    @Query private var pantry: [PantryItem]
    @Query private var meals: [CookedMeal]
    @AppStorage(AppSettings.weeklyBudgetKey) private var weeklyBudget = 0
    @AppStorage(AppSettings.weeklyMealGoalKey) private var mealGoal = 0

    @State private var chat = ChatModel()
    @State private var draft = ""
    @State private var selected: RecipeMatch?
    @FocusState private var typing: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.s) {
                        if chat.messages.isEmpty { welcome }
                        ForEach(chat.messages) { message in
                            MessageRow(message: message) { open($0) }
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
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: chat.messages.count) { scrollToEnd(proxy) }
                .onChange(of: chat.isThinking) { scrollToEnd(proxy) }
            }
            suggestionChips
            inputBar
        }
        .recipeCookingFlow(selected: $selected, diets: app.profile.dietSet)
        .tapFeedback(chat.messages.count)
        .task {
            await chat.prewarm()
            await askDebugQuestions()
        }
    }

    /// `-chatAsk "What can I make?|How's my streak?"` asks those on open, one
    /// after another (debug builds only).
    private func askDebugQuestions() async {
        #if DEBUG
        guard chat.messages.isEmpty, let list = UserDefaults.standard.string(forKey: "chatAsk") else { return }
        for question in list.split(separator: "|").map(String.init) {
            let kitchen = KitchenSnapshot.capture(pantry: pantry, meals: meals, profile: app.profile,
                                                  weeklyBudget: weeklyBudget, mealGoal: mealGoal)
            await chat.send(question, kitchen: kitchen)
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
                 ? "I can see your pantry, every recipe, and how your week's going. Ask me anything food-related."
                 : "I can see your pantry, every recipe, and how your week's going. Tap a question below or ask your own.")
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
            TextField("Ask Nutmeg…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($typing)
                .submitLabel(.send)
                .onSubmit { send(draft) }
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
    }

    // MARK: - Actions

    private func send(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !chat.isThinking else { return }
        let kitchen = KitchenSnapshot.capture(pantry: pantry, meals: meals, profile: app.profile,
                                              weeklyBudget: weeklyBudget, mealGoal: mealGoal)
        draft = ""
        Task { await chat.send(text, kitchen: kitchen) }
    }

    /// Opens a suggested recipe, matched against the pantry as it is now.
    private func open(_ recipeID: String) {
        guard let recipe = RecipeStore.recipe(withID: recipeID) else { return }
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

/// One message, with Nutmeg's small avatar beside his, and any recipes he
/// suggested as compact cards underneath.
private struct MessageRow: View {
    let message: ChatMessage
    let onOpen: (String) -> Void

    var body: some View {
        if message.role == .person {
            ChatBubble(text: message.text, fromNutmeg: false)
        } else {
            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                NutmegView()
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ChatBubble(text: message.text, fromNutmeg: true)
                    ForEach(message.recipeIDs, id: \.self) { id in
                        if let recipe = RecipeStore.recipe(withID: id) {
                            ChatRecipeCard(recipe: recipe) { onOpen(id) }
                        }
                    }
                }
            }
        }
    }
}

private struct ChatRecipeCard: View {
    let recipe: Recipe
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                Text(recipe.emoji)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Theme.Palette.amber.opacity(0.25), in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text(recipe.title)
                        .font(.subheadline.bold())
                    Text("\(recipe.minutes) min · \(recipe.costText)")
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
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
