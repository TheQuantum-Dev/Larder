//
//  TryItView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import PhotosUI
import SwiftUI

/// The "try it now" moment in onboarding: a first real photo of a fridge or
/// shelf, scanned on the spot, with no account needed. Typing things in by
/// hand is offered right next to the camera, not tucked away.
struct TryItView: View {
    /// Called with the items the person confirmed.
    let onFinish: ([ResolvedItem]) -> Void

    @State private var model = TryItModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showBarcodeScanner = false

    var body: some View {
        ZStack {
            switch model.phase {
            case .prompt:
                prompt
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            case .scanning(let image):
                ScanningView(image: image)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            case .review(let review):
                ScanConfirmView(review: review) { onFinish(review.selected) }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: model.phaseID)
        .onAppear {
            PantryScanner.prewarm()
            openDebugPhoto()
        }
        .onDisappear { model.cancel() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let image { model.begin(with: image) }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showBarcodeScanner) {
            BarcodeScanView(
                onFinish: { items in
                    showBarcodeScanner = false
                    model.foundByBarcode(items)
                },
                onCancel: { showBarcodeScanner = false })
                .ignoresSafeArea()
        }
    }

    // MARK: - Prompt

    private var prompt: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: 0)

            NutmegView()
                .frame(height: 160)

            VStack(spacing: Theme.Spacing.xs) {
                Text("Let's peek in your fridge!")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Snap your fridge, cupboard or a shelf. I'll spot what's there, and you fix anything I get wrong.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                if let problem = model.problem {
                    Text(problem)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .padding(.top, Theme.Spacing.xs)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.s) {
                if CameraPicker.isAvailable {
                    Button("Take a photo") { showCamera = true }
                        .buttonStyle(PillButtonStyle())
                }

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(CameraPicker.isAvailable ? "Choose from your photos" : "Choose a photo")
                }
                .buttonStyle(PillButtonStyle(fill: CameraPicker.isAvailable ? Theme.Palette.softAmber : Theme.Palette.amber))

                if BarcodeScannerView.isAvailable {
                    Button("Scan a barcode instead") { showBarcodeScanner = true }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .frame(minHeight: 44)
                }

                Button("I'll add things by hand") { model.startByHand() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(minHeight: 44)

                Text("Your photo is read on your phone and never uploaded.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
        }
        .padding(Theme.Spacing.s)
    }

    // MARK: - Loading photos

    private func load(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = CGImage.load(from: data) {
            model.begin(with: image)
        } else {
            model.photoUnusable()
        }
    }

    /// `-tryItPhoto /path/to/photo.jpg` scans a photo straight away (debug builds only).
    private func openDebugPhoto() {
        #if DEBUG
        guard model.phaseID == 0,
              let path = UserDefaults.standard.string(forKey: "tryItPhoto"),
              let image = CGImage.load(from: URL(fileURLWithPath: path)) else { return }
        model.begin(with: image)
        #endif
    }
}

/// The wait while a scan runs: the person's photo, a peeking Nutmeg, and a
/// line that changes every few seconds so it never feels stuck.
private struct ScanningView: View {
    let image: CGImage

    @State private var messageIndex = 0

    private let messages = [
        "Peeking inside…",
        "Squinting at the labels…",
        "Counting what's there…",
        "Almost got it…",
    ]

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: 0)

            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .strokeBorder(Theme.Palette.amber, lineWidth: 3)
                }

            NutmegView(mood: .peeking)
                .frame(height: 120)

            Text(messages[messageIndex])
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
                .contentTransition(.opacity)
                .id(messageIndex)

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.s)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    messageIndex = min(messageIndex + 1, messages.count - 1)
                }
            }
        }
    }
}
