//
//  CookTimerMetadata.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import AlarmKit
import Foundation

/// What a Cook Mode timer's alarm carries, so the lock screen can say which
/// recipe and step it's for. The app and the Live Activity both compile this
/// one file, so they agree on the type.
nonisolated struct CookTimerMetadata: AlarmMetadata {
    var recipeTitle: String
    var recipeEmoji: String
    /// Counted from 1, the way the screen shows it.
    var step: Int
    var stepSnippet: String
}
