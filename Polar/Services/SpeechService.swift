import AVFoundation
import Foundation
#if os(iOS)
import Speech

@MainActor
final class SpeechService {
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var engine: AVAudioEngine?
    private var listenTask: Task<Void, Never>?
    private var streamContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private(set) var transcript = ""

    func start() async throws {
        transcript = ""
        guard await AVAudioApplication.requestRecordPermission() else {
            throw SpeechDenied()
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "fr-FR")) ?? Locale(identifier: "fr-FR")
        let transcriber = DictationTranscriber(locale: locale, preset: .shortDictation)
        self.transcriber = transcriber
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer

        let engine = AVAudioEngine()
        self.engine = engine
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        streamContinuation = continuation
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            continuation.yield(AnalyzerInput(buffer: buffer))
        }
        engine.prepare()
        try engine.start()

        listenTask = Task {
            do {
                for try await result in transcriber.results {
                    transcript = String(result.text.characters)
                }
            } catch {}
        }
        Task {
            try? await analyzer.start(inputSequence: stream)
        }
    }

    func stop() async -> String {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        streamContinuation?.finish()
        listenTask?.cancel()
        await analyzer?.cancelAndFinishNow()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        analyzer = nil
        engine = nil
        transcriber = nil
        return transcript
    }
}

private struct SpeechDenied: Error {}
#endif
