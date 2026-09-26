//
//  OnlineRecipeViews.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import SwiftUI

/// A recipe's picture: its photo when it has one, and its emoji in an amber
/// circle otherwise, or while the photo is still on its way.
struct RecipeThumb: View {
    let emoji: String
    var imageURL: String?
    var size: CGFloat = 60
    var emojiSize: CGFloat = 34

    var body: some View {
        Group {
            if let url = imageURL.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: face
                    }
                }
            } else {
                face
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var face: some View {
        Text(emoji)
            .font(.system(size: emojiSize))
            .frame(width: size, height: size)
            .background(Theme.Palette.amber.opacity(0.25), in: Circle())
    }
}

/// Marks a recipe that was looked up online rather than being one of Larder's own.
struct OnlineTag: View {
    var body: some View {
        Label("Online", systemImage: "globe")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            .padding(.horizontal, Theme.Spacing.xs)
            .frame(minHeight: 20)
            .background(Theme.Palette.background, in: Capsule())
    }
}

/// The credit the recipe service asks for on its free plan.
struct SpoonacularCredit: View {
    static let url = URL(string: "https://spoonacular.com/food-api")!

    var body: some View {
        HStack(spacing: 4) {
            Text("Recipes found with")
            Link("spoonacular.com", destination: Self.url)
                .underline()
        }
        .font(.footnote)
        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
        .tint(Theme.Palette.textPrimary.opacity(0.75))
    }
}

/// Asks, once and kindly, whether to look up extra recipes online.
struct OnlineOptInCard: View {
    let onTurnOn: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            NutmegView()
                .frame(width: 60)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Want more ideas?")
                    .font(.headline)
                Text("I can look up extra recipes online that fit your goal and what's in your pantry. Only ingredient names go out, never your photos.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Turn on online recipes", action: onTurnOn)
                    .buttonStyle(PillButtonStyle(fill: Theme.Palette.softAmber))
                Text("You can turn it off any time in Settings.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.6))
            }
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

/// Nutmeg saying what's going on with the online recipes, so there's never a
/// silent gap where they should be.
struct OnlineNote: View {
    let text: String
    var showsProgress = false

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            NutmegView(mood: showsProgress ? .peeking : .idle)
                .frame(width: 60)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

/// A favorite that came from online. Its recipe isn't kept between sessions, so
/// tapping it fetches it again.
struct SavedOnlineRow: View {
    let note: RecipeNote
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                RecipeThumb(emoji: note.emoji, imageURL: note.imageURL, size: 50, emojiSize: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text(note.title)
                        .font(.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text("Saved from online")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.4))
                }
            }
            .padding(Theme.Spacing.s)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
