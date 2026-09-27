//
//  TryItView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import PhotosUI
import SwiftData
import SwiftUI

/// The pantry scan: the "try it now" moment in onboarding, and "Update pantry"
/// later on. Photos of the fridge or shelves are scanned on the spot, as many
/// as the person likes, with no account needed. Typing things in by hand is
/// offered right next to the camera, not tucked away.
struct TryItView: View {
    /// Onboarding's first scan, or topping up the pantry later from the app.
    var mode = ScanMode.onboarding
    /// Called with the confirmed review.
    let onFinish: (ScanReview) -> Void

    @State private var model = TryItModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showBarcodeScanner = false
    @Query(sort: \PantryItem.addedAt) private var pantry: [PantryItem]

    var body: some View {
        ZStack {
            switch model.phase {
            case .prompt:
                prompt
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            case .scanning:
                ScanningView(queue: model.queue)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            case .review(let review):
                ScanConfirmView(review: review, mode: mode,
                                onScanBarcode: BarcodeScannerView.isAvailable ? { showBarcodeScanner = true } : nil) {
                    onFinish(review)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: model.phaseID)
        .onAppear {
            // Onboarding starts a pantry from scratch; an update checks against what's there.
            if mode == .update { model.pantry = pantry.map { PantrySnapshot($0) } }
            PantryScanner.prewarm()
            openDebugPhotos()
        }
        .onDisappear { model.cancel() }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            PantryCameraView(queue: model.queue,
                             onDone: {
                                 showCamera = false
                                 model.finishPhotos()
                             },
                             onCancel: {
                                 showCamera = false
                                 model.startOver()
                             })
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
                Text(mode == .update ? "Update your pantry" : "Let's peek in your fridge!")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(mode == .update
                     ? "Snap the fridge, the cupboard, every shelf. I'll start looking while you shoot, then you check what I found."
                     : "Snap your fridge, cupboard or a shelf, as many photos as you like. I'll spot what's there, and you fix anything I get wrong.")
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
                if PantryCameraView.isAvailable {
                    Button("Take photos") { showCamera = true }
                        .buttonStyle(PillButtonStyle())
                }

                PhotosPicker(selection: $pickerItems, maxSelectionCount: ScanQueue.limit, matching: .images) {
                    Text(PantryCameraView.isAvailable ? "Choose from your photos" : "Choose photos")
                }
                .buttonStyle(PillButtonStyle(fill: PantryCameraView.isAvailable ? Theme.Palette.softAmber : Theme.Palette.amber))

                if BarcodeScannerView.isAvailable {
                    Button("Scan a barcode instead") { showBarcodeScanner = true }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .frame(minHeight: 44)
                }

                Button(mode == .update ? "I'll update it by hand" : "I'll add things by hand") { model.startByHand() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(minHeight: 44)

                Text("Photos are read on your phone and never uploaded.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
            }
        }
        .padding(Theme.Spacing.s)
    }

    // MARK: - Loading photos

    private func load(_ items: [PhotosPickerItem]) async {
        defer { pickerItems = [] }
        var loaded = 0
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = CGImage.load(from: data) {
                model.add(image)
                loaded += 1
            }
        }
        if loaded > 0 { model.finishPhotos() } else { model.photoUnusable() }
    }

    /// `-tryItPhoto /path/a.jpg,/path/b.jpg` scans those photos straight away
    /// (debug builds only).
    private func openDebugPhotos() {
        #if DEBUG
        guard model.phaseID == 0, let paths = UserDefaults.standard.string(forKey: "tryItPhoto") else { return }
        for path in paths.split(separator: ",") {
            if let image = CGImage.load(from: URL(fileURLWithPath: String(path))) { model.add(image) }
        }
        model.finishPhotos()
        #endif
    }
}

/// Where the scan was opened from, which changes a few words: onboarding's
/// first scan leads to recipes, and a later one updates the pantry.
enum ScanMode {
    case onboarding, update
}

/// The wait while photos are scanned: the photos in a little stack, a peeking
/// Nutmeg, and a line that changes every few seconds so it never feels stuck.
private struct ScanningView: View {
    let queue: ScanQueue

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

            ZStack {
                let shots = Array(queue.shots.prefix(3))
                ForEach(Array(shots.enumerated()), id: \.element.id) { index, shot in
                    let offset = Double(index) - Double(shots.count - 1) / 2
                    Image(decorative: shot.image, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.cardRadius)
                                .strokeBorder(Theme.Palette.amber, lineWidth: 3)
                        }
                        .rotationEffect(.degrees(offset * 6))
                        .offset(x: offset * 20)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)

            NutmegView(mood: .peeking)
                .frame(height: 120)

            VStack(spacing: Theme.Spacing.xs) {
                Text(messages[messageIndex])
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(.opacity)
                    .id(messageIndex)
                if queue.shots.count > 1 {
                    Text("\(queue.finishedCount) of \(queue.shots.count) photos done")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.75))
                        .contentTransition(.numericText())
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.s)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: queue.finishedCount)
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
