//
//  Theme.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Observation
import SwiftUI
import UIKit

/// Design tokens for the visual system. The colors follow the look Nutmeg is
/// wearing (see `AppTheme`), each with a light and a dark version; sage and
/// coral are the same everywhere.
enum Theme {
    enum Palette {
        private static var theme: AppTheme { ThemeStore.shared.theme }

        static var background: Color { theme.background }
        static var surface: Color { theme.surface }
        static var textPrimary: Color { theme.textPrimary }
        /// The look's main color: amber, coral, snow blue or pumpkin.
        static var amber: Color { theme.accent }
        /// Reserved for the paywall.
        static let coral = Color(.coral)
        /// Success states only.
        static let sage = Color(.sage)
        /// Text and icons that sit on top of the main color or its soft version.
        static var onAccent: Color { theme.onAccent }
        /// A lighter main color for the quieter of two buttons. It's light in
        /// dark mode too, so what sits on it uses `onAccent`.
        static var softAmber: Color { theme.softAccent }
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

/// The colors for one of Nutmeg's looks, taken from its app icon, as hex
/// values for light and dark mode.
nonisolated struct AppTheme: Sendable {
    struct Pair: Sendable {
        let light: UInt32
        let dark: UInt32

        init(_ light: UInt32, _ dark: UInt32) {
            self.light = light
            self.dark = dark
        }

        init(_ both: UInt32) {
            self.init(both, both)
        }
    }

    let backgroundHex: Pair
    let surfaceHex: Pair
    let textHex: Pair
    let accentHex: UInt32
    let onAccentHex: UInt32

    let background: Color
    let surface: Color
    let textPrimary: Color
    let accent: Color
    let softAccent: Color
    let onAccent: Color

    /// How far toward white the soft version of the main color goes.
    static let softMix = 0.55

    init(background: Pair, surface: Pair, text: Pair, accent: UInt32, onAccent: UInt32) {
        backgroundHex = background
        surfaceHex = surface
        textHex = text
        accentHex = accent
        onAccentHex = onAccent
        self.background = Self.color(background)
        self.surface = Self.color(surface)
        textPrimary = Self.color(text)
        self.accent = Self.color(Pair(accent))
        softAccent = Self.color(Pair(Self.mixWithWhite(accent, by: Self.softMix)))
        self.onAccent = Self.color(Pair(onAccent))
    }

    /// Nutmeg's everyday amber, on cream or dark brown.
    static let amber = AppTheme(background: Pair(0xFBF3E6, 0x1F1610), surface: Pair(0xF5E6D3, 0x2E2219),
                                text: Pair(0x3B2A1A, 0xFBF3E6), accent: 0xF0A83A, onAccent: 0x3B2A1A)
    /// Warm coral, on a blush background.
    static let coral = AppTheme(background: Pair(0xFDF1EC, 0x21130F), surface: Pair(0xF8DDD2, 0x34201A),
                                text: Pair(0x3B2A1A, 0xFDF1EC), accent: 0xE86A45, onAccent: 0x2A1510)
    /// The snow icon's navy night and a snowy blue.
    static let snow = AppTheme(background: Pair(0xEEF4FA, 0x0E1A2B), surface: Pair(0xDCE8F4, 0x1A2C44),
                               text: Pair(0x1F3A5F, 0xEAF2FA), accent: 0x5B9BD5, onAccent: 0x0E1A2B)
    /// Pumpkin, on the harvest icon's browns.
    static let harvest = AppTheme(background: Pair(0xFBEEE2, 0x1C0F07), surface: Pair(0xF2D9C3, 0x2E1A0D),
                                  text: Pair(0x4A2410, 0xFBEEE2), accent: 0xE2822B, onAccent: 0x3B1A08)

    static func mixWithWhite(_ hex: UInt32, by amount: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let value = Double((hex >> shift) & 0xFF)
            return UInt32((value + (255 - value) * amount).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    /// A color that switches with light and dark mode by itself.
    private static func color(_ pair: Pair) -> Color {
        let light = uiColor(pair.light)
        let dark = uiColor(pair.dark)
        return Color(UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}

extension NutmegLook {
    var theme: AppTheme {
        switch self {
        case .amber: .amber
        case .coral: .coral
        case .snow: .snow
        case .harvest: .harvest
        }
    }
}

/// Which look's colors the app is showing. It's observed, so every view that
/// reads a `Theme.Palette` color redraws the moment the look changes.
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    var look = NutmegLook.amber

    var theme: AppTheme { look.theme }
}
