//
//  PantryCameraView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import AVFoundation
import SwiftUI
import UIKit

/// A camera that stays open: snap the fridge, the cupboard, the shelf, and
/// each photo starts being looked at the moment it's taken. A strip along the
/// bottom shows every photo, with a tick once it's done.
///
/// UIKit's picker closes after every shot, so this uses AVFoundation directly:
/// a capture session feeding a live preview, and a photo output for the shots.
struct PantryCameraView: View {
    let queue: ScanQueue
    let onDone: () -> Void
    let onCancel: () -> Void

    @State private var camera = CameraSession()
    @State private var state = CameraState.starting
    @State private var flash = false
    @State private var shutterCount = 0
    @State private var confirmingDiscard = false

    enum CameraState { case starting, ready, denied }

    /// False on the Simulator and on devices without a camera.
    static var isAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if state == .denied {
                deniedMessage
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                Color.white.opacity(flash ? 0.7 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            VStack(spacing: Theme.Spacing.s) {
                topBar
                Spacer(minLength: 0)
                if !queue.shots.isEmpty { thumbnails }
                controls
            }
            .padding(Theme.Spacing.s)
        }
        .statusBarHidden()
        .sensoryFeedback(.impact(weight: .medium), trigger: shutterCount)
        .task {
            state = await camera.start() ? .ready : .denied
        }
        .onDisappear { camera.stop() }
        .alert("Leave without these photos?", isPresented: $confirmingDiscard) {
            Button("Keep taking photos", role: .cancel) {}
            Button("Leave", role: .destructive, action: onCancel)
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack {
            Button {
                queue.shots.isEmpty ? onCancel() : (confirmingDiscard = true)
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibilityLabel("Close the camera")
            Spacer()
            Text(hint)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.Spacing.s)
                .frame(minHeight: 40)
                .background(.black.opacity(0.4), in: Capsule())
        }
    }

    private var hint: String {
        if queue.isFull { return "That's plenty. Tap Done!" }
        switch queue.shots.count {
        case 0: return "Snap your fridge or a shelf"
        case 1: return "Got it! Another shelf?"
        default: return "\(queue.shots.count) photos. Keep going or tap Done"
        }
    }

    private var thumbnails: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(queue.shots) { shot in
                        Thumbnail(shot: shot).id(shot.id)
                    }
                }
            }
            .onChange(of: queue.shots.count) { _, _ in
                withAnimation { proxy.scrollTo(queue.shots.last?.id, anchor: .trailing) }
            }
        }
        .frame(height: 70)
    }

    private var controls: some View {
        HStack {
            Color.clear.frame(width: 90, height: 1)
            Spacer()
            Button(action: shoot) {
                ZStack {
                    Circle().strokeBorder(.white, lineWidth: 5).frame(width: 78, height: 78)
                    Circle().fill(.white).frame(width: 62, height: 62)
                }
            }
            .disabled(state != .ready || queue.isFull)
            .opacity(state != .ready || queue.isFull ? 0.4 : 1)
            .accessibilityLabel("Take a photo")
            Spacer()
            Button(action: onDone) {
                Text(queue.shots.isEmpty ? "Done" : "Done (\(queue.shots.count))")
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.onAccent)
                    .padding(.horizontal, Theme.Spacing.s)
                    .frame(width: 90, height: 50)
                    .background(Theme.Palette.amber, in: Capsule())
            }
            .disabled(queue.shots.isEmpty)
            .opacity(queue.shots.isEmpty ? 0.4 : 1)
        }
        .padding(.bottom, Theme.Spacing.xs)
    }

    private var deniedMessage: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: "camera")
                .font(.largeTitle)
            Text("Larder can't use the camera")
                .font(.headline)
            Text("You can turn it on in the Settings app, or close this and choose photos instead.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.amber)
            }
        }
        .foregroundStyle(.white)
        .padding(Theme.Spacing.l)
    }

    private func shoot() {
        shutterCount += 1
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        withAnimation(.easeIn(duration: 0.25).delay(0.08)) { flash = false }
        Task {
            if let image = await camera.capture() {
                queue.add(image)
            }
        }
    }
}

/// One photo in the strip: a spinner while it's being looked at, then how
/// many things it spotted.
private struct Thumbnail: View {
    let shot: ScanQueue.Shot

    var body: some View {
        Image(decorative: shot.image, scale: 1)
            .resizable()
            .scaledToFill()
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(.white, lineWidth: 2)
            }
            .overlay(alignment: .bottomTrailing) {
                Group {
                    if let result = shot.result {
                        Text("\(result.items.count)")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.Palette.onAccent)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(Theme.Palette.amber, in: Circle())
                    } else {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 22, height: 22)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                }
                .offset(x: 4, y: 4)
            }
            .padding(4)
            .accessibilityElement()
            .accessibilityLabel(shot.result.map { "Photo \(shot.id + 1): \($0.items.count) things spotted" }
                                ?? "Photo \(shot.id + 1): still looking")
    }
}

/// The live camera picture, as a UIKit view SwiftUI can host.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}
}

/// The capture session and photo output. Starting and stopping a session can
/// take a moment, so that happens on its own queue rather than the main one.
/// AVFoundation's classes aren't marked safe to share between threads, so
/// this class promises it only touches them on that queue (or, for the
/// preview, hands the session to the main thread once).
nonisolated final class CameraSession: NSObject, @unchecked Sendable, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "larder.camera")
    private let lock = NSLock()
    private var waiting: [Int64: CheckedContinuation<CGImage?, Never>] = [:]
    private var configured = false

    /// Asks for permission if needed, then starts the camera. False if it can't.
    func start() async -> Bool {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
        return await withCheckedContinuation { continuation in
            queue.async {
                if !self.configured { self.configured = self.configure() }
                if self.configured, !self.session.isRunning { self.session.startRunning() }
                continuation.resume(returning: self.configured)
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configure() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input), session.canAddOutput(output) else { return false }
        session.addInput(input)
        session.addOutput(output)
        output.maxPhotoQualityPrioritization = .speed
        return true
    }

    /// Takes a photo, upright and scaled down, ready to scan. Nil if it failed.
    func capture() async -> CGImage? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .speed
                self.lock.withLock { self.waiting[settings.uniqueID] = continuation }
                self.output.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // The photo data carries its rotation, and loading it this way applies it.
        let image = photo.fileDataRepresentation().flatMap { CGImage.load(from: $0) }
        let continuation = lock.withLock { waiting.removeValue(forKey: photo.resolvedSettings.uniqueID) }
        continuation?.resume(returning: error == nil ? image : nil)
    }
}
