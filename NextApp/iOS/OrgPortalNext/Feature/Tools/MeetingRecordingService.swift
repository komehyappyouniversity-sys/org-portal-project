import AVFAudio
import Foundation
import Speech

public struct MeetingRecordingPermissions: Sendable {
    public let microphoneGranted: Bool
    public let speechRecognitionGranted: Bool
}

public protocol SpeechTranscriptionProvider: AnyObject {
    var transcript: String { get }
    var notice: String? { get }
    func start(locale: Locale)
    func append(_ buffer: AVAudioPCMBuffer)
    func stop()
}

public final class iOSOnDeviceTranscriptionProvider:
    NSObject,
    SpeechTranscriptionProvider,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storedTranscript = ""
    private var storedNotice: String?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    public var transcript: String {
        lock.withLock { storedTranscript }
    }

    public var notice: String? {
        lock.withLock { storedNotice }
    }

    public func start(locale: Locale) {
        stop()
        lock.withLock {
            storedTranscript = ""
            storedNotice = nil
        }
        let recognizer = SFSpeechRecognizer(locale: locale)
        guard let recognizer, recognizer.supportsOnDeviceRecognition else {
            lock.withLock {
                storedNotice =
                    "この端末では端末内文字起こしを利用できません。録音後に手入力できます。"
            }
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request
        recognitionTask = recognizer.recognitionTask(with: request) {
            [weak self] result, error in
            guard let self else { return }
            self.lock.withLock {
                if let result {
                    self.storedTranscript = result.bestTranscription.formattedString
                }
                if error != nil {
                    self.storedNotice =
                        "端末内の文字起こしを継続できません。録音は保存されます。"
                }
            }
        }
    }

    public func append(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    public func stop() {
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionRequest = nil
        recognitionTask = nil
    }
}

/// Owns the real-time audio callback without inheriting the UI's main-actor
/// isolation. AVAudioEngine invokes its tap on an internal audio queue.
private final class MeetingAudioTapProcessor: @unchecked Sendable {
    private let audioFile: AVAudioFile
    private let transcriptionProvider: SpeechTranscriptionProvider
    private let transcriptionEnabled: Bool
    private let onWriteFailure: @MainActor @Sendable () -> Void
    private let failureLock = NSLock()
    private var didReportWriteFailure = false

    init(
        audioFile: AVAudioFile,
        transcriptionProvider: SpeechTranscriptionProvider,
        transcriptionEnabled: Bool,
        onWriteFailure: @escaping @MainActor @Sendable () -> Void
    ) {
        self.audioFile = audioFile
        self.transcriptionProvider = transcriptionProvider
        self.transcriptionEnabled = transcriptionEnabled
        self.onWriteFailure = onWriteFailure
    }

    func makeTapBlock() -> AVAudioNodeTapBlock {
        { [weak self] buffer, _ in
            self?.process(buffer)
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        do {
            try audioFile.write(from: buffer)
        } catch {
            reportWriteFailureOnce()
            return
        }
        if transcriptionEnabled {
            transcriptionProvider.append(buffer)
        }
    }

    private func reportWriteFailureOnce() {
        let shouldReport = failureLock.withLock {
            guard !didReportWriteFailure else { return false }
            didReportWriteFailure = true
            return true
        }
        guard shouldReport else { return }
        Task { @MainActor [onWriteFailure] in
            onWriteFailure()
        }
    }
}

@MainActor
public final class MeetingRecordingService: NSObject, ObservableObject {
    @Published public private(set) var isRecording = false
    public var transcript: String { transcriptionProvider.transcript }
    public var transcriptionNotice: String? {
        manualTranscriptionNotice ?? transcriptionProvider.notice
    }

    public var onInterruption: (() -> Void)?

    private let audioEngine = AVAudioEngine()
    private var audioTapProcessor: MeetingAudioTapProcessor?
    private let transcriptionProvider: SpeechTranscriptionProvider
    private var manualTranscriptionNotice: String?
    private nonisolated(unsafe) var interruptionObserver: NSObjectProtocol?

    public init(transcriptionProvider: SpeechTranscriptionProvider) {
        self.transcriptionProvider = transcriptionProvider
        super.init()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                _ = self.stop()
                self.onInterruption?()
            }
        }
    }

    public override convenience init() {
        self.init(transcriptionProvider: iOSOnDeviceTranscriptionProvider())
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    /// Permission callbacks are delivered by the system on an arbitrary queue.
    /// Keep this method nonisolated so the Speech callback does not inherit
    /// `MeetingRecordingService`'s main-actor isolation and trap at runtime.
    public nonisolated static func requestPermissions() async -> MeetingRecordingPermissions {
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard microphone else {
            return MeetingRecordingPermissions(
                microphoneGranted: false,
                speechRecognitionGranted: false
            )
        }
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        return MeetingRecordingPermissions(
            microphoneGranted: microphone,
            speechRecognitionGranted: speech
        )
    }

    public func start(
        at url: URL,
        locale: Locale = Locale(identifier: "ja-JP"),
        transcriptionEnabled: Bool = true
    ) throws {
        guard !isRecording else { return }
        manualTranscriptionNotice = nil

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)

        if transcriptionEnabled {
            transcriptionProvider.start(locale: locale)
        } else {
            transcriptionProvider.stop()
            manualTranscriptionNotice =
                "音声認識は許可されていません。録音後に議事録を手入力できます。"
        }

        let processor = MeetingAudioTapProcessor(
            audioFile: audioFile,
            transcriptionProvider: transcriptionProvider,
            transcriptionEnabled: transcriptionEnabled
        ) { [weak self] in
            guard let self else { return }
            self.manualTranscriptionNotice =
                "録音ファイルへの書き込みに失敗しました。"
            _ = self.stop()
            self.onInterruption?()
        }
        audioTapProcessor = processor
        input.installTap(
            onBus: 0,
            bufferSize: 1_024,
            format: format,
            block: processor.makeTapBlock()
        )
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            audioTapProcessor = nil
            transcriptionProvider.stop()
            try? session.setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            throw error
        }
        isRecording = true
    }

    @discardableResult
    public func stop() -> String {
        guard isRecording else {
            if audioTapProcessor != nil {
                audioEngine.inputNode.removeTap(onBus: 0)
                audioTapProcessor = nil
                transcriptionProvider.stop()
            }
            return transcript
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        transcriptionProvider.stop()
        audioTapProcessor = nil
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
        isRecording = false
        return transcript
    }
}
