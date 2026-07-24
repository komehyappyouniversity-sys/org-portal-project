import Foundation
import Model

@MainActor
public protocol MeetingMinutesRepository {
    func fetchAll() async throws -> [MeetingMinutes]
    func save(_ minutes: MeetingMinutes) async throws
    func delete(id: UUID) async throws
}

public protocol MeetingRecordingDraftStoring: Sendable {
    func load() throws -> MeetingRecordingDraft?
    func save(_ draft: MeetingRecordingDraft) throws
    func delete() throws
}
