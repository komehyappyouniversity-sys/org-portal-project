import Foundation

public struct MeetingMinutes: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var userId: String
    public var title: String
    public var recordingStartAt: Date
    public var recordingEndAt: Date
    public var recordingDurationSeconds: Int
    public var audioFileLocalPath: String
    public var transcriptText: String
    public var pdfFileLocalPath: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        userId: String = "guest",
        title: String = "",
        recordingStartAt: Date = .now,
        recordingEndAt: Date = .now,
        recordingDurationSeconds: Int = 0,
        audioFileLocalPath: String = "",
        transcriptText: String = "",
        pdfFileLocalPath: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.recordingStartAt = recordingStartAt
        self.recordingEndAt = recordingEndAt
        self.recordingDurationSeconds = recordingDurationSeconds
        self.audioFileLocalPath = audioFileLocalPath
        self.transcriptText = transcriptText
        self.pdfFileLocalPath = pdfFileLocalPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func validated(now: Date = .now) throws -> MeetingMinutes {
        var value = self
        value.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        value.transcriptText = transcriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.title.isEmpty else { throw MeetingMinutesValidationError.titleRequired }
        guard !value.audioFileLocalPath.isEmpty else {
            throw MeetingMinutesValidationError.audioFileRequired
        }
        guard value.recordingDurationSeconds >= 0 else {
            throw MeetingMinutesValidationError.invalidDuration
        }
        guard value.recordingEndAt >= value.recordingStartAt else {
            throw MeetingMinutesValidationError.invalidDateRange
        }
        value.updatedAt = now
        return value
    }
}

public enum MeetingMinutesValidationError: Error, Equatable {
    case titleRequired
    case audioFileRequired
    case invalidDuration
    case invalidDateRange
}

public struct MeetingRecordingDraft: Equatable, Codable, Sendable {
    public var id: UUID
    public var userId: String
    public var startedAt: Date
    public var audioFileLocalPath: String
    public var transcriptText: String
    public var recordingDurationSeconds: Int
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        userId: String = "guest",
        startedAt: Date = .now,
        audioFileLocalPath: String,
        transcriptText: String = "",
        recordingDurationSeconds: Int = 0,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.startedAt = startedAt
        self.audioFileLocalPath = audioFileLocalPath
        self.transcriptText = transcriptText
        self.recordingDurationSeconds = recordingDurationSeconds
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case startedAt
        case audioFileLocalPath
        case transcriptText
        case recordingDurationSeconds
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        userId = try values.decodeIfPresent(String.self, forKey: .userId) ?? "guest"
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        audioFileLocalPath = try values.decode(String.self, forKey: .audioFileLocalPath)
        transcriptText = try values.decodeIfPresent(String.self, forKey: .transcriptText) ?? ""
        recordingDurationSeconds =
            try values.decodeIfPresent(Int.self, forKey: .recordingDurationSeconds) ?? 0
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? startedAt
    }
}
