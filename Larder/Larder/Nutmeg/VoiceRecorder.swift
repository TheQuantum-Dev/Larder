//
//  VoiceRecorder.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import AVFoundation
import Observation
import Speech

/// Talking to Nutmeg: listens to the microphone and turns speech into text as
/// it's said, entirely on the phone (the recognizer is told never to send
/// audio anywhere). The words show up live, and the person sends them like a
/// typed message.
@Observable
final class VoiceRecorder {
    enum State: Equatable {
        case idle
        case listening
        /// Stopped (by a pause, or the time limit) with words ready to send.
        case finished
        /// The microphone or speech permission was turned down.
        case denied
    }

    private(set) var state = State.idle
    private(set) var transcript = ""
    /// Recent loudness, 0 to 1, oldest first, for the waveform.
    private(set) var levels: [Double] = Array(repeating: 0, count: VoiceRecorder.barCount)

    static let barCount = 28
    /// A pause this long after some words ends the recording.
    static let pauseLimit: Duration = .seconds(2)
    /// Nobody needs to talk to Nutmeg for more than a minute at once.
    static let timeLimit: Duration = .seconds(60)

    @ObservationIgnored private var session: SpeechSession?
    @ObservationIgnored private var watcher: Task<Void, Never>?
    @ObservationIgnored private var lastChange = ContinuousClock.now

    /// True when this phone can turn speech into text without the internet.
    /// Without that, the mic is simply not offered.
    static var isSupported: Bool {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "fakeVoice") != nil { return true }
        #endif
        return SpeechSession.recognizer?.supportsOnDeviceRecognition ?? false
    }

    var isActive: Bool { state == .listening || state == .finished }

    func start() async {
        guard state != .listening else { return }
        #if DEBUG
        if let fake = UserDefaults.standard.string(forKey: "fakeVoice") {
            transcript = fake
            levels = (0..<Self.barCount).map { 0.2 + 0.6 * abs(sin(Double($0) * 0.7)) }
            state = .listening
            return
        }
        #endif
        guard await SpeechSession.askPermission() else {
            state = .denied
            return
        }
        // The chime goes first: while the mic is on, the phone plays nothing.
        SoundPlayer.recordStart()
        try? await Task.sleep(for: .milliseconds(180))
        transcript = ""
        levels = Array(repeating: 0, count: Self.barCount)
        // The session holds on to this recorder only while it's listening:
        // stopping lets go of the session, and with it these callbacks.
        let recorder = self
        let session = SpeechSession(
            onText: { text in
                Task { @MainActor in recorder.heard(text) }
            },
            onLevel: { level in
                Task { @MainActor in recorder.push(level) }
            })
        guard session.start() else {
            state = .idle
            return
        }
        self.session = session
        state = .listening
        lastChange = .now
        watchForPause()
    }

    /// Stops listening and hands back what was said.
    @discardableResult
    func finish() -> String {
        stopListening()
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        transcript = ""
        state = .idle
        return text
    }

    /// Throws it all away.
    func cancel() {
        stopListening()
        transcript = ""
        state = .idle
    }

    func clearDenied() {
        if state == .denied { state = .idle }
    }

    private func heard(_ text: String) {
        guard state == .listening, text != transcript else { return }
        transcript = text
        lastChange = .now
    }

    private func push(_ level: Double) {
        guard state == .listening else { return }
        levels.removeFirst()
        levels.append(level)
    }

    /// Ends the recording after a pause once something's been said, or at
    /// the time limit, leaving the words ready to send.
    private func watchForPause() {
        watcher?.cancel()
        let started = ContinuousClock.now
        watcher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, self.state == .listening else { return }
                let quiet = ContinuousClock.now - self.lastChange >= Self.pauseLimit && !self.transcript.isEmpty
                if quiet || ContinuousClock.now - started >= Self.timeLimit {
                    self.stopListening()
                    self.state = self.transcript.isEmpty ? .idle : .finished
                    return
                }
            }
        }
    }

    private func stopListening() {
        watcher?.cancel()
        watcher = nil
        let wasListening = session != nil
        session?.stop()
        session = nil
        if wasListening { SoundPlayer.recordStop() }
        levels = Array(repeating: 0, count: Self.barCount)
    }
}

/// The microphone and the recognizer. Audio arrives on its own thread, so
/// this class keeps to itself and only reports back through the two
/// callbacks, which hop to the main actor.
nonisolated final class SpeechSession: @unchecked Sendable {
    static let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private let engine = AVAudioEngine()
    private let request = SFSpeechAudioBufferRecognitionRequest()
    private var task: SFSpeechRecognitionTask?
    private let onText: @Sendable (String) -> Void
    private let onLevel: @Sendable (Double) -> Void

    init(onText: @escaping @Sendable (String) -> Void, onLevel: @escaping @Sendable (Double) -> Void) {
        self.onText = onText
        self.onLevel = onLevel
    }

    /// Asks for the microphone and for speech recognition, if not asked before.
    static func askPermission() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func start() -> Bool {
        guard let recognizer = Self.recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            return false
        }
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audio.setActive(true, options: .notifyOthersOnDeactivation)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [request, onLevel] buffer, _ in
                request.append(buffer)
                onLevel(Self.loudness(of: buffer))
            }
            engine.prepare()
            try engine.start()
        } catch {
            restoreAudio()
            return false
        }
        task = recognizer.recognitionTask(with: request) { [onText] result, _ in
            if let result { onText(result.bestTranscription.formattedString) }
        }
        return true
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request.endAudio()
        task?.cancel()
        task = nil
        restoreAudio()
    }

    /// Back to the quiet, mix-with-anything session the app's sounds use.
    private func restoreAudio() {
        let audio = AVAudioSession.sharedInstance()
        try? audio.setCategory(.ambient, options: [.mixWithOthers])
        try? audio.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// How loud a slice of audio is, from 0 to 1, on a scale that suits speech.
    private static func loudness(of buffer: AVAudioPCMBuffer) -> Double {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += samples[i] * samples[i] }
        let rms = sqrt(sum / Float(buffer.frameLength))
        let decibels = 20 * log10(max(rms, 0.000_01))
        return Double(min(1, max(0, (decibels + 50) / 40)))
    }
}
