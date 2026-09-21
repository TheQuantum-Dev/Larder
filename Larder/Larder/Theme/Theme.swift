//
//  Theme.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// Design tokens for the visual system. The colors live in the asset catalog
/// with light and dark variants; the brand colors are the same in both.
enum Theme {
    enum Palette {
        static let background = Color(.background)
        static let surface = Color(.surface)
        static let textPrimary = Color(.textPrimary)
        static let amber = Color(.amber)
        /// Reserved for the paywall.
        static let coral = Color(.coral)
        /// Success states only.
        static let sage = Color(.sage)
        /// Text and icons that sit on top of amber or coral.
        static let onAccent = Color(.onAccent)
        /// A lighter amber for the quieter of two buttons.
        static let softAmber = Color(.amber).mix(with: .white, by: 0.55)
    }

    /// Every margin and padding in the app is a multiple of 10.
    enum Spacing {
        static let xs: CGFloat = 10
        static let s: CGFloat = 20
        static let m: CGFloat = 30
        static let l: CGFloat = 40
    }

    static let cardRadius: CGFloat = 20

    /// How far the pressable button face sits above its darker edge.
    static let buttonDepth: CGFloat = 6
}
