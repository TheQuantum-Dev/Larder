//
//  FounderNote.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

/// The note from the builder that appears right before the paywall. It should
/// sound like a person, so it's kept here in one place, in plain text.
nonisolated enum FounderNote {
    static let title = "Hey, it's Joshua"
    static let name = "Joshua"

    static let paragraphs = [
        "Hey, I'm Joshua. I'm a high school student, and I built Larder on my own.",
        "I wanted to get healthier, but every calorie app I tried either didn't fit what I needed or assumed a budget students don't have. And like everyone, I'd open the fridge, see nothing, close it, and open it again hoping something had changed. That's where Larder came from.",
        "I hope it makes cooking feel easy and relaxing again, even on a tight budget. Scanning and recipes are free, always. Larder Plus is how I keep building it. If it's not for you, that's completely fine.",
    ]
}
