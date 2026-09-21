//
//  FounderNote.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

/// The note from the builder that appears right before the paywall. It should
/// sound like a person, so it's kept here in one place, in plain text, for
/// the builder to edit into their own words.
nonisolated enum FounderNote {
    static let title = "A quick note from my creator"
    static let name = "Joshua"

    // A first draft using only what's already public about the project.
    // Rewrite it in your own voice before the video and the submission.
    static let paragraphs = [
        "Hi, I'm Joshua. I'm building Larder on my own for the RevenueCat Shipaton.",
        "It's for students who want to eat well on a tight budget: point your camera at what you have, and get something you can cook right now.",
        "Scanning and recipes stay free, always. Larder Plus is how I keep building it. If it's not for you, that's completely okay.",
    ]
}
