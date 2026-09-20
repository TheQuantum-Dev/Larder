//
//  ProgressBar.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// A slim bar that springs to its new width when the progress changes.
struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.surface)
                Capsule()
                    .fill(Theme.Palette.amber)
                    .frame(width: proxy.size.width * progress)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: progress)
        }
        .frame(height: 10)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

#Preview {
    ProgressBar(progress: 0.4)
        .padding()
        .background(Theme.Palette.background)
}
