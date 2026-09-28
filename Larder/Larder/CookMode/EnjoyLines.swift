//
//  EnjoyLines.swift
//  Larder
//
//  Created by Joshua Samuel on 9/28/26.
//

import Foundation
import SwiftUI

/// What Nutmeg says when a meal is ready. They come round in a shuffled
/// order, so the same line doesn't turn up twice in a row, or even often.
nonisolated enum EnjoyLines {
    static let all = [
        "Enjoy!", "Dig in!", "Bon appétit!", "Looks amazing!", "Smells so good!",
        "You made that!", "Chef's kiss!", "Eat up!", "Nailed it!", "Tuck in!",
        "That's a win!", "So proud of you!",
    ]

    private static let key = "enjoyLineQueue"

    /// The next line, from a queue that reshuffles once it runs out.
    static func next(defaults: UserDefaults = .standard) -> String {
        var queue = (defaults.array(forKey: key) as? [Int])?.filter { all.indices.contains($0) } ?? []
        if queue.isEmpty {
            let last = defaults.integer(forKey: key + "Last")
            queue = Array(all.indices).shuffled()
            // A fresh shuffle never starts with the line that just played.
            if queue.first == last, queue.count > 1 { queue.swapAt(0, 1) }
        }
        let index = queue.removeFirst()
        defaults.set(queue, forKey: key)
        defaults.set(index, forKey: key + "Last")
        return all[index]
    }
}

/// A little rounded speech bubble with a tail pointing at the speaker.
struct SpeechBubble: View {
    let text: String
    /// True when the speaker is on the left, so the tail points that way.
    var pointsLeft = true

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0x3B / 255, green: 0x2A / 255, blue: 0x1A / 255))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white, in: Capsule())
            .overlay(alignment: pointsLeft ? .bottomLeading : .bottomTrailing) {
                Triangle()
                    .fill(.white)
                    .frame(width: 14, height: 10)
                    .rotationEffect(.degrees(pointsLeft ? 30 : -30))
                    .offset(x: pointsLeft ? 6 : -6, y: 6)
            }
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            .accessibilityLabel("Nutmeg says \(text)")
    }

    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.closeSubpath()
            return p
        }
    }
}
