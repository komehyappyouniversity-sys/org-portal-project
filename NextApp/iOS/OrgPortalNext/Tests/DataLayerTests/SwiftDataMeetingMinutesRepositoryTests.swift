import Foundation
import SwiftData
import XCTest
@testable import DataLayer
import Model

@MainActor
final class SwiftDataMeetingMinutesRepositoryTests: XCTestCase {
    func testSaveFetchAndDeleteAlsoRemovesAudio() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MeetingMinutesRecord.self,
            configurations: configuration
        )
        let repository = SwiftDataMeetingMinutesRepository(modelContainer: container)
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("meeting-\(UUID().uuidString).caf")
        try Data("audio".utf8).write(to: audioURL)
        let now = Date()
        let minutes = MeetingMinutes(
            title: "保存テスト",
            recordingStartAt: now,
            recordingEndAt: now.addingTimeInterval(30),
            recordingDurationSeconds: 30,
            audioFileLocalPath: audioURL.path,
            transcriptText: "本文"
        )

        try await repository.save(minutes)
        let saved = try await repository.fetchAll()
        XCTAssertEqual(saved.map(\.title), ["保存テスト"])

        try await repository.delete(id: minutes.id)
        let remaining = try await repository.fetchAll()
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
    }

    func testInterruptedDraftCanBeRestored() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("meeting-draft-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalMeetingRecordingStore(rootURL: root)
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let draft = MeetingRecordingDraft(
            startedAt: startedAt,
            audioFileLocalPath: root.appendingPathComponent("draft.caf").path,
            transcriptText: "復旧する文字起こし",
            updatedAt: startedAt.addingTimeInterval(10)
        )

        try store.save(draft)
        XCTAssertEqual(try store.load(), draft)
        try store.delete()
        XCTAssertNil(try store.load())
    }
}
