import AVFAudio
import DataLayer
import Foundation
import Model

@MainActor
public final class MeetingMinutesFeatureModel: ObservableObject {
    @Published public private(set) var minutes: [MeetingMinutes] = []
    @Published public private(set) var draft: MeetingRecordingDraft?
    @Published public private(set) var isRecording = false
    @Published public private(set) var elapsedSeconds = 0
    @Published public private(set) var liveTranscript = ""
    @Published public private(set) var notice: String?
    @Published public private(set) var errorMessage: String?

    public let recorder: MeetingRecordingService
    private let repository: MeetingMinutesRepository
    private let recordingStore: LocalMeetingRecordingStore
    private var timer: Timer?

    public init(
        repository: MeetingMinutesRepository,
        recordingStore: LocalMeetingRecordingStore,
        recorder: MeetingRecordingService = MeetingRecordingService()
    ) {
        self.repository = repository
        self.recordingStore = recordingStore
        self.recorder = recorder
        recorder.onInterruption = { [weak self] in
            self?.finishInterruptedRecording()
        }
    }

    public func load() async {
        do {
            minutes = try await repository.fetchAll()
            let restoredDraft = try recordingStore.load()
            draft = restoredDraft
            elapsedSeconds = restoredDraft?.recordingDurationSeconds ?? 0
            liveTranscript = restoredDraft?.transcriptText ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func startRecording() async -> Bool {
        let permissions = await MeetingRecordingService.requestPermissions()
        guard permissions.microphoneGranted else {
            errorMessage =
                "録音にはマイクの許可が必要です。設定アプリから許可してください。"
            return false
        }
        do {
            let id = UUID()
            let audioURL = try recordingStore.newTemporaryAudioURL(id: id)
            let value = MeetingRecordingDraft(
                id: id,
                audioFileLocalPath: audioURL.path
            )
            try recordingStore.save(value)
            draft = value
            try recorder.start(
                at: audioURL,
                transcriptionEnabled: permissions.speechRecognitionGranted
            )
            isRecording = true
            elapsedSeconds = 0
            liveTranscript = ""
            notice = recorder.transcriptionNotice
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
                [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            return true
        } catch {
            errorMessage = "録音を開始できませんでした。\(error.localizedDescription)"
            return false
        }
    }

    public func stopRecording() {
        liveTranscript = recorder.stop()
        isRecording = false
        timer?.invalidate()
        timer = nil
        persistDraft()
    }

    public func saveDraft(title: String, transcript: String) async throws {
        guard let draft else { return }
        let now = Date()
        let duration = max(draft.recordingDurationSeconds, elapsedSeconds)
        let destination = try recordingStore.moveAudio(
            from: URL(fileURLWithPath: draft.audioFileLocalPath),
            minutesId: draft.id
        )
        let value = try MeetingMinutes(
            id: draft.id,
            userId: draft.userId,
            title: title,
            recordingStartAt: draft.startedAt,
            recordingEndAt: draft.startedAt.addingTimeInterval(TimeInterval(duration)),
            recordingDurationSeconds: duration,
            audioFileLocalPath: destination.path,
            transcriptText: transcript,
            createdAt: draft.startedAt,
            updatedAt: now
        ).validated(now: now)
        try await repository.save(value)
        try recordingStore.delete()
        self.draft = nil
        liveTranscript = ""
        elapsedSeconds = 0
        await load()
    }

    public func update(_ value: MeetingMinutes) async throws {
        try await repository.save(value)
        await load()
    }

    public func delete(_ value: MeetingMinutes) async {
        do {
            try await repository.delete(id: value.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func discardDraft() {
        guard let draft else { return }
        do {
            try recordingStore.discard(draft)
            self.draft = nil
            liveTranscript = ""
            elapsedSeconds = 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func report(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    public func clearError() {
        errorMessage = nil
    }

    private func tick() {
        elapsedSeconds += 1
        liveTranscript = recorder.transcript
        notice = recorder.transcriptionNotice
        if elapsedSeconds.isMultiple(of: 10) {
            persistDraft()
        }
    }

    private func persistDraft() {
        guard var draft else { return }
        draft.transcriptText = liveTranscript
        draft.recordingDurationSeconds = elapsedSeconds
        draft.updatedAt = .now
        do {
            try recordingStore.save(draft)
            self.draft = draft
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishInterruptedRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        liveTranscript = recorder.transcript
        persistDraft()
        notice = "録音が中断されました。未保存の録音として復旧できます。"
    }
}
