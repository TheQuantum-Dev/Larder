//
//  HomeGreeting.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

/// What Nutmeg says at the top of home. There's always something to say,
/// including when the pantry is empty.
nonisolated enum HomeGreeting {
    static func text(pantryCount: Int, readyCount: Int) -> String {
        if pantryCount == 0 { return "Your pantry's empty for now. Let's fill it up!" }
        switch readyCount {
        case 0: return "Nothing's fully ready yet, but you're close. Take a look!"
        case 1: return "You can make 1 thing right now."
        default: return "You can make \(readyCount) things right now."
        }
    }
}
