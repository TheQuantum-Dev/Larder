//
//  LookSplash.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import SwiftUI

/// The moment after launch for anyone wearing a look other than amber. iOS
/// shows the same launch screen for everyone (the everyday Nutmeg on cream or
/// dark brown), so this picks up exactly where it leaves off: same spot, same
/// size, and then Nutmeg hops into his outfit while the background turns to
/// the look's colors, before it all fades into the app.
struct LookSplash: View {
    let look: NutmegLook
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dressed = false
    @State private var cheer = 0
    @State private var fading = false

    /// The launch image's size in points, so the hand-over is seamless.
    private static let launchSize = CGSize(width: 231, height: 180)

    var body: some View {
        ZStack {
            // The launch screen's own background, then the look's on top of it.
            Color(.background)
            look.theme.background
                .opacity(dressed ? 1 : 0)
            NutmegView(skin: dressed ? look.skin : .amber, cheer: cheer, showsWeather: dressed)
                .frame(width: Self.launchSize.width, height: Self.launchSize.height)
                .scaleEffect(dressed && !reduceMotion ? 1.06 : 1)
        }
        .ignoresSafeArea()
        .opacity(fading ? 0 : 1)
        .allowsHitTesting(!fading)
        .accessibilityHidden(true)
        .task { await play() }
    }

    private func play() async {
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 250))
        if !reduceMotion { cheer += 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { dressed = true }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 750))
        withAnimation(.easeOut(duration: 0.35)) { fading = true }
        try? await Task.sleep(for: .milliseconds(350))
        onDone()
    }
}
