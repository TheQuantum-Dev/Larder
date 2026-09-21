//
//  ConfettiView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftUI

/// Confetti that falls once over whatever it's layered on. The pieces are
/// spread out by fixed arithmetic, not chance, so it looks the same every time.
struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fallen = false

    private struct Piece: Identifiable {
        let id: Int
        let x: Double
        let delay: Double
        let duration: Double
        let size: Double
        let spin: Double
        let color: Color
    }

    private static let colors: [Color] = [
        Theme.Palette.amber, Theme.Palette.softAmber, Theme.Palette.sage, Color(red: 0xF6 / 255, green: 0xC0 / 255, blue: 0x67 / 255),
    ]

    private let pieces: [Piece] = (0..<44).map { i in
        func fraction(_ factor: Double, _ offset: Double = 0) -> Double {
            (Double(i) * factor + offset).truncatingRemainder(dividingBy: 1)
        }
        return Piece(id: i,
                     x: fraction(0.618, 0.1),
                     delay: fraction(0.37) * 0.9,
                     duration: 1.8 + fraction(0.53) * 1.4,
                     size: 8 + fraction(0.71) * 8,
                     spin: 200 + fraction(0.29) * 400,
                     color: colors[i % colors.count])
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 1.6)
                        .rotationEffect(.degrees(fallen ? piece.spin : 0))
                        .position(x: piece.x * proxy.size.width,
                                  y: fallen ? proxy.size.height + 40 : -40)
                        .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: fallen)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if !reduceMotion { fallen = true }
        }
    }
}
