//
//  NutmegChatView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

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

/// The chat itself, for Plus. Filled in next: the intent engine, then
/// Foundation Models on devices that have it.
struct NutmegChatScreen: View {
    var body: some View {
        NutmegChatIntro()
    }
}
