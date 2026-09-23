//
//  BarcodeScanView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/22/26.
//

import SwiftUI

/// A live barcode scan session: point at as many packaged items as you like,
/// see them collect at the bottom, then confirm them all at once on the
/// usual review screen. Nothing here is final until that confirm step.
struct BarcodeScanView: View {
    /// Called with everything found, once the person taps Done.
    let onFinish: ([ResolvedItem]) -> Void
    let onCancel: () -> Void

    @State private var found: [ResolvedItem] = []
    @State private var seenBarcodes: Set<String> = []
    @State private var miss: String?
    @State private var missTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if BarcodeScannerView.isAvailable {
                BarcodeScannerView(onRecognize: handle)
                    .ignoresSafeArea()
            } else {
                Theme.Palette.background.ignoresSafeArea()
            }

            VStack {
                topBar
                Spacer()
                if BarcodeScannerView.isAvailable {
                    bottomPanel
                } else {
                    unavailablePanel
                }
            }
            .padding(Theme.Spacing.s)
        }
        .sensoryFeedback(.selection, trigger: found.count)
    }

    private var topBar: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(Theme.Spacing.xs)
                .background(.black.opacity(0.4), in: Capsule())
            Spacer()
        }
    }

    @ViewBuilder
    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(found.isEmpty ? "Point at a barcode" : "Found \(found.count)")
                .font(.headline)
                .foregroundStyle(.white)
                .shadow(radius: 4)

            if let miss {
                Text(miss)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .frame(minHeight: 30)
                    .background(.black.opacity(0.5), in: Capsule())
            }

            if !found.isEmpty {
                FlowLayout {
                    ForEach(found) { item in
                        Label("\(item.emoji) \(item.name)", systemImage: "checkmark")
                            .labelStyle(.titleOnly)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .frame(minHeight: 40)
                            .background(Theme.Palette.sage, in: Capsule())
                    }
                }

                Button("Done") { onFinish(found) }
                    .buttonStyle(PillButtonStyle())
            }
        }
        .padding(Theme.Spacing.s)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var unavailablePanel: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text("Barcode scanning needs a real camera, so it's not available here.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textPrimary)
            Button("Back", action: onCancel)
                .buttonStyle(PillButtonStyle())
        }
        .padding(Theme.Spacing.s)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func handle(_ barcode: String) {
        guard !seenBarcodes.contains(barcode) else { return }
        seenBarcodes.insert(barcode)
        Task {
            switch await OpenFoodFactsClient.lookup(barcode: barcode) {
            case .success(let product):
                let item = product.resolvedItem
                if !found.contains(item) { found.append(item) }
            case .failure:
                seenBarcodes.remove(barcode)
                showMiss()
            }
        }
    }

    private func showMiss() {
        missTask?.cancel()
        miss = "Couldn't find that one. You can add it by hand instead."
        missTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { miss = nil }
        }
    }
}
