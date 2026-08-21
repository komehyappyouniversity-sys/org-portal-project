import Foundation

public struct PostAttachment: Equatable, Codable, Sendable {
    public let type: String
    public let name: String
    public let url: URL

    public init(type: String, name: String, url: URL) {
        self.type = type
        self.name = name
        self.url = url
    }
}

public struct AdminReply: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let postId: String
    public let adminUserId: String
    public let adminName: String?
    public let body: String
    public let createdAt: Date?

    public init(
        id: String,
        postId: String,
        adminUserId: String,
        adminName: String?,
        body: String,
        createdAt: Date?
    ) {
        self.id = id
        self.postId = postId
        self.adminUserId = adminUserId
        self.adminName = adminName
        self.body = body
        self.createdAt = createdAt
    }
}

public struct MemberPost: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let communityId: String
    public let authorUserId: String
    public let authorName: String
    public let title: String
    public let body: String
    public let attachments: [PostAttachment]
    public let status: String
    public let legacyAdminReply: String?
    public let memberHasReadReply: Bool
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: String,
        communityId: String,
        authorUserId: String,
        authorName: String,
        title: String,
        body: String,
        attachments: [PostAttachment] = [],
        status: String = "submitted",
        legacyAdminReply: String? = nil,
        memberHasReadReply: Bool = true,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.communityId = communityId
        self.authorUserId = authorUserId
        self.authorName = authorName
        self.title = title
        self.body = body
        self.attachments = attachments
        self.status = status
        self.legacyAdminReply = legacyAdminReply
        self.memberHasReadReply = memberHasReadReply
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var hasUnreadReply: Bool {
        !(legacyAdminReply ?? "").isEmpty && !memberHasReadReply
    }

    public func canEdit(userId: String) -> Bool {
        authorUserId == userId
    }
}

public struct PublicPost: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let authorUserId: String
    public let authorName: String
    public let title: String
    public let categoryId: String?
    public let body: String
    public let attachments: [PostAttachment]
    public let createdAt: Date?

    public init(
        id: String,
        authorUserId: String,
        authorName: String,
        title: String,
        categoryId: String?,
        body: String,
        attachments: [PostAttachment] = [],
        createdAt: Date? = nil
    ) {
        self.id = id
        self.authorUserId = authorUserId
        self.authorName = authorName
        self.title = title
        self.categoryId = categoryId
        self.body = body
        self.attachments = attachments
        self.createdAt = createdAt
    }
}

public struct RadioProgram: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let communityId: String
    public let title: String
    public let description: String
    public let imageUrl: String
    public let audioUrl: URL
    public let broadcastStartAt: Date
    public let broadcastEndAt: Date

    public init(
        id: String,
        communityId: String,
        title: String,
        description: String,
        imageUrl: String,
        audioUrl: URL,
        broadcastStartAt: Date,
        broadcastEndAt: Date
    ) {
        self.id = id
        self.communityId = communityId
        self.title = title
        self.description = description
        self.imageUrl = imageUrl
        self.audioUrl = audioUrl
        self.broadcastStartAt = broadcastStartAt
        self.broadcastEndAt = broadcastEndAt
    }
}

public enum RadioPlaybackPolicy {
    public static func isPlayable(_ program: RadioProgram, at date: Date) -> Bool {
        date >= program.broadcastStartAt
    }
}

public struct RadioPlaybackRecord: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let userId: String
    public let programId: String
    public let lastPositionSeconds: Double
    public let playCount: Int
    public let lastPlayedAt: Date?

    public init(
        id: String = UUID().uuidString,
        userId: String,
        programId: String,
        lastPositionSeconds: Double = 0,
        playCount: Int = 0,
        lastPlayedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.programId = programId
        self.lastPositionSeconds = lastPositionSeconds
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
    }
}

public enum RadioPlaybackRecordPolicy {
    public static func started(
        existing: RadioPlaybackRecord?,
        userId: String,
        programId: String,
        at date: Date
    ) -> RadioPlaybackRecord {
        RadioPlaybackRecord(
            id: existing?.id ?? UUID().uuidString,
            userId: userId,
            programId: programId,
            lastPositionSeconds: max(0, existing?.lastPositionSeconds ?? 0),
            playCount: (existing?.playCount ?? 0) + 1,
            lastPlayedAt: date
        )
    }

    public static func updatingPosition(
        _ existing: RadioPlaybackRecord,
        positionSeconds: Double,
        at date: Date
    ) -> RadioPlaybackRecord {
        RadioPlaybackRecord(
            id: existing.id,
            userId: existing.userId,
            programId: existing.programId,
            lastPositionSeconds: max(0, positionSeconds.isFinite ? positionSeconds : 0),
            playCount: existing.playCount,
            lastPlayedAt: date
        )
    }
}

public enum RadioPlaybackInterruptionPolicy {
    public static func shouldResume(
        wasPlayingBeforeInterruption: Bool,
        systemAllowsResume: Bool
    ) -> Bool {
        wasPlayingBeforeInterruption && systemAllowsResume
    }
}

public enum RadioPlaybackPresentation {
    public static let playAction = "再生"
    public static let pauseAction = "一時停止"
    public static let resumeAction = "再開"
    public static let stopAction = "停止"
    public static let playingStatus = "再生中"
    public static let pausedStatus = "一時停止中"

    public static func primaryAction(
        isPlayable: Bool,
        isActive: Bool,
        isPlaying: Bool
    ) -> String {
        if !isPlayable { return "配信前" }
        if isActive && isPlaying { return pauseAction }
        if isActive { return resumeAction }
        return playAction
    }

    public static func status(isPlaying: Bool) -> String {
        isPlaying ? playingStatus : pausedStatus
    }
}
