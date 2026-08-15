import Foundation

public enum UserStage: String, CaseIterable, Codable, Sendable {
    case guest
    case member
    case creator
    case manager
    case owner
}

public enum AccountAccessState: String, CaseIterable, Codable, Sendable {
    case guest
    case registered
    case pendingApproval
    case rejected
    case member
}

public enum CommunityMembershipStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case approved
    case rejected
}

public struct Community: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let code: String
    public let name: String
    public let description: String
    public let logoURL: URL?
    public let homepageURL: URL?
    public let isActive: Bool
    public let joinEnabled: Bool
    public let surfingVisible: Bool

    public init(
        id: String,
        code: String,
        name: String,
        description: String = "",
        logoURL: URL? = nil,
        homepageURL: URL? = nil,
        isActive: Bool = true,
        joinEnabled: Bool = false,
        surfingVisible: Bool = false
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.description = description
        self.logoURL = logoURL
        self.homepageURL = homepageURL
        self.isActive = isActive
        self.joinEnabled = joinEnabled
        self.surfingVisible = surfingVisible
    }

    public func matchesPublicSearch(_ query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }
        return [name, code, description].contains {
            $0.localizedCaseInsensitiveContains(normalized)
        }
    }
}

public struct CommunityAuditLog: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let action: String
    public let actorUserId: String?
    public let targetUserId: String?
    public let communityId: String
    public let createdAt: Date?

    public init(
        id: String,
        action: String,
        actorUserId: String? = nil,
        targetUserId: String? = nil,
        communityId: String,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.action = action
        self.actorUserId = actorUserId
        self.targetUserId = targetUserId
        self.communityId = communityId
        self.createdAt = createdAt
    }
}

public struct CommunityMembership: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let communityId: String
    public let userId: String
    public let status: CommunityMembershipStatus
    public let role: String
    public let joinedAt: Date?
    public let applicantName: String?
    public let applicantFurigana: String?
    public let applicantEmail: String?
    public let createdAt: Date?
    public let categoryIds: Set<String>

    public init(
        id: String,
        communityId: String,
        userId: String,
        status: CommunityMembershipStatus,
        role: String = "member",
        joinedAt: Date? = nil,
        applicantName: String? = nil,
        applicantFurigana: String? = nil,
        applicantEmail: String? = nil,
        createdAt: Date? = nil,
        categoryIds: Set<String> = []
    ) {
        self.id = id
        self.communityId = communityId
        self.userId = userId
        self.status = status
        self.role = role
        self.joinedAt = joinedAt
        self.applicantName = applicantName
        self.applicantFurigana = applicantFurigana
        self.applicantEmail = applicantEmail
        self.createdAt = createdAt
        self.categoryIds = categoryIds
    }
}

public enum AnnouncementPublishScope: String, Codable, CaseIterable, Sendable {
    case `public`
    case memberAll
    case category
    case individual
}

public struct AnnouncementAttachment: Equatable, Codable, Sendable {
    public let type: String
    public let name: String
    public let url: URL

    public init(type: String, name: String, url: URL) {
        self.type = type
        self.name = name
        self.url = url
    }
}

public struct Announcement: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let communityId: String
    public let title: String
    public let body: String
    public let publishScope: AnnouncementPublishScope
    public let targetCategoryIds: Set<String>
    public let targetUserIds: Set<String>
    public let attachments: [AnnouncementAttachment]
    public let zoomURL: URL?
    public let videoURL: URL?
    public let createdAt: Date?

    public init(
        id: String,
        communityId: String,
        title: String,
        body: String,
        publishScope: AnnouncementPublishScope,
        targetCategoryIds: Set<String> = [],
        targetUserIds: Set<String> = [],
        attachments: [AnnouncementAttachment] = [],
        zoomURL: URL? = nil,
        videoURL: URL? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.communityId = communityId
        self.title = title
        self.body = body
        self.publishScope = publishScope
        self.targetCategoryIds = targetCategoryIds
        self.targetUserIds = targetUserIds
        self.attachments = attachments
        self.zoomURL = zoomURL
        self.videoURL = videoURL
        self.createdAt = createdAt
    }

    public func isVisible(
        userId: String?,
        categoryIds: Set<String>,
        isApprovedMember: Bool
    ) -> Bool {
        switch publishScope {
        case .public:
            return true
        case .memberAll:
            return isApprovedMember
        case .category:
            return isApprovedMember && !targetCategoryIds.isDisjoint(with: categoryIds)
        case .individual:
            return isApprovedMember && userId.map(targetUserIds.contains) == true
        }
    }
}

public struct AnnouncementReadState: Equatable, Codable, Sendable {
    public let userId: String
    public let announcementId: String
    public let readAt: Date

    public init(userId: String, announcementId: String, readAt: Date) {
        self.userId = userId
        self.announcementId = announcementId
        self.readAt = readAt
    }
}

public struct CommunityAdminAccess: Equatable, Codable, Sendable {
    public static let memberReviewPermission = "memberReview"
    public static let legacyMemberReviewPermission = "メンバー閲覧・承認"

    public let communityId: String
    public let userId: String
    public let role: String
    public let permissions: Set<String>
    public let isLegacyFullAccess: Bool

    public init(
        communityId: String,
        userId: String,
        role: String,
        permissions: Set<String>,
        isLegacyFullAccess: Bool = false
    ) {
        self.communityId = communityId
        self.userId = userId
        self.role = role
        self.permissions = permissions
        self.isLegacyFullAccess = isLegacyFullAccess
    }

    public var canReviewMembers: Bool {
        role == "owner"
            || isLegacyFullAccess
            || permissions.contains(Self.memberReviewPermission)
            || permissions.contains(Self.legacyMemberReviewPermission)
    }
}

public struct CommunityAdmin: Identifiable, Equatable, Codable, Sendable {
    public var id: String { userId }
    public let userId: String
    public let role: String
    public let permissions: Set<String>
    public let isActive: Bool

    public init(
        userId: String,
        role: String = "admin",
        permissions: Set<String> = [],
        isActive: Bool = true
    ) {
        self.userId = userId
        self.role = role
        self.permissions = permissions
        self.isActive = isActive
    }
}

public struct DistributedVideo: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let communityId: String
    public let videoTitle: String
    public let description: String
    public let embedHtml: String
    public let videoUrl: String
    public let vimeoUrl: String
    public let providerVideoId: String
    public let videoType: String
    public let thumbnailUrl: String
    public let isPremium: Bool
    public let primaryCategoryId: String
    public let secondaryCategoryId: String
    public let createdAt: Date?
    public let updatedAt: Date?
    public let isPublished: Bool
    public let isMembersOnly: Bool
    public let sortOrder: Int

    public var title: String {
        videoTitle
    }

    public var videoURL: URL? {
        URL(string: vimeoUrl)
            ?? URL(string: videoUrl)
    }

    public var vimeoVideoId: String {
        providerVideoId
    }

    public var thumbnailURL: URL? {
        URL(string: thumbnailUrl)
    }

    public init(
        id: String,
        communityId: String,
        videoTitle: String,
        description: String = "",
        embedHtml: String = "",
        videoUrl: String = "",
        vimeoUrl: String = "",
        providerVideoId: String = "",
        videoType: String = "distributed_vimeo",
        thumbnailUrl: String = "",
        primaryCategoryId: String = "",
        secondaryCategoryId: String = "",
        isPremium: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        isPublished: Bool = false,
        isMembersOnly: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.communityId = communityId
        self.videoTitle = videoTitle
        self.description = description
        self.embedHtml = embedHtml
        self.videoUrl = videoUrl
        self.vimeoUrl = vimeoUrl
        self.providerVideoId = providerVideoId
        self.videoType = videoType
        self.thumbnailUrl = thumbnailUrl
        self.primaryCategoryId = primaryCategoryId
        self.secondaryCategoryId = secondaryCategoryId
        self.isPremium = isPremium
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPublished = isPublished
        self.isMembersOnly = isMembersOnly
        self.sortOrder = sortOrder
    }
}

public enum UsageLogEventType: String, Codable, CaseIterable, Sendable {
    case videoDetailOpened = "video_detail_opened"
    case videoPlaybackStarted = "video_playback_started"
    case videoPosition = "video_position"
    case videoCompleted = "video_completed"
    case radioPlayed = "radio_played"
}

public enum UsageLogValidationError: Error, Equatable, Sendable {
    case missingID
    case missingUserID
    case missingTargetID
    case invalidPositionSeconds
}

public struct UsageLog: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let userId: String
    public let eventType: UsageLogEventType
    public let targetId: String
    public let positionSeconds: Double
    public let occurredAt: Date

    public init(
        id: String,
        userId: String,
        eventType: UsageLogEventType,
        targetId: String,
        positionSeconds: Double = 0,
        occurredAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.eventType = eventType
        self.targetId = targetId
        self.positionSeconds = positionSeconds
        self.occurredAt = occurredAt
    }

    public func validate() throws {
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw UsageLogValidationError.missingID
        }
        if userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw UsageLogValidationError.missingUserID
        }
        if targetId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw UsageLogValidationError.missingTargetID
        }
        if !positionSeconds.isFinite || positionSeconds < 0 {
            throw UsageLogValidationError.invalidPositionSeconds
        }
    }
}

public struct BookingEvent: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let communityId: String
    public let title: String
    public let description: String
    public let eventDate: Date?
    public let feeAmount: Int
    public let paymentRequired: Bool
    public let zoomURL: URL?
    public let isPublished: Bool

    public init(
        id: String,
        communityId: String,
        title: String,
        description: String = "",
        eventDate: Date? = nil,
        feeAmount: Int = 0,
        paymentRequired: Bool = false,
        zoomURL: URL? = nil,
        isPublished: Bool = false
    ) {
        self.id = id
        self.communityId = communityId
        self.title = title
        self.description = description
        self.eventDate = eventDate
        self.feeAmount = feeAmount
        self.paymentRequired = paymentRequired
        self.zoomURL = zoomURL
        self.isPublished = isPublished
    }
}

public struct BookingSlot: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let eventId: String
    public let startAt: Date?
    public let endAt: Date?
    public let capacity: Int
    public let reservedCount: Int
    public let paidCount: Int
    public let isOpen: Bool

    public init(
        id: String,
        eventId: String,
        startAt: Date? = nil,
        endAt: Date? = nil,
        capacity: Int = 0,
        reservedCount: Int = 0,
        paidCount: Int = 0,
        isOpen: Bool = true
    ) {
        self.id = id
        self.eventId = eventId
        self.startAt = startAt
        self.endAt = endAt
        self.capacity = capacity
        self.reservedCount = reservedCount
        self.paidCount = paidCount
        self.isOpen = isOpen
    }

    public var remainingCount: Int {
        max(capacity - reservedCount, 0)
    }

    public var isFull: Bool {
        capacity <= 0 || reservedCount >= capacity
    }
}

public struct BookingReservation: Equatable, Codable, Sendable {
    public let eventId: String
    public let slotId: String
    public let userId: String
    public let status: String
    public let purchaseStatus: String

    public init(
        eventId: String = "",
        slotId: String,
        userId: String,
        status: String,
        purchaseStatus: String = "not-required"
    ) {
        self.eventId = eventId
        self.slotId = slotId
        self.userId = userId
        self.status = status
        self.purchaseStatus = purchaseStatus
    }
}

public struct VideoQuestion: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let communityId: String
    public let memberUid: String
    public let videoId: String
    public let videoTitle: String
    public let playbackSeconds: Double
    public let memoText: String
    public let questionText: String
    public let answerText: String
    public let createdAt: Date?
    public let answeredAt: Date?
    public let syncStatus: VideoQuestionSyncStatus
    public let clientRequestId: String

    public var isAnswered: Bool {
        !answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        id: String,
        communityId: String,
        memberUid: String,
        videoId: String,
        videoTitle: String,
        playbackSeconds: Double = 0,
        memoText: String = "",
        questionText: String,
        answerText: String = "",
        createdAt: Date? = nil,
        answeredAt: Date? = nil,
        syncStatus: VideoQuestionSyncStatus = .synced,
        clientRequestId: String = ""
    ) {
        self.id = id
        self.communityId = communityId
        self.memberUid = memberUid
        self.videoId = videoId
        self.videoTitle = videoTitle
        self.playbackSeconds = playbackSeconds
        self.memoText = memoText
        self.questionText = questionText
        self.answerText = answerText
        self.createdAt = createdAt
        self.answeredAt = answeredAt
        self.syncStatus = syncStatus
        self.clientRequestId = clientRequestId
    }
}

public enum VideoQuestionSyncStatus: String, Codable, Sendable {
    case draft
    case sending
    case synced
    case failed

    public var requiresSync: Bool {
        self != .synced
    }
}

public struct VimeoVideoMemo: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let text: String
    public let playbackSeconds: Double
    public let createdAtMillis: Int64
    public let updatedAtMillis: Int64
    public let syncStatus: VimeoVideoMemoSyncStatus

    public var isPendingSync: Bool {
        syncStatus == .pendingSync
    }

    public init(
        id: String,
        text: String,
        playbackSeconds: Double,
        createdAtMillis: Int64,
        updatedAtMillis: Int64,
        syncStatus: VimeoVideoMemoSyncStatus = .synced
    ) {
        self.id = id
        self.text = text
        self.playbackSeconds = playbackSeconds
        self.createdAtMillis = createdAtMillis
        self.updatedAtMillis = updatedAtMillis
        self.syncStatus = syncStatus
    }

    public var createdAt: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAtMillis) / 1000)
    }

    public var updatedAt: Date {
        Date(timeIntervalSince1970: TimeInterval(updatedAtMillis) / 1000)
    }
}

public enum VimeoVideoMemoSyncStatus: String, Codable, Sendable {
    case synced
    case pendingSync
}

public enum CommunityCodeParser {
    public static func parse(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let components = URLComponents(string: trimmed), components.scheme != nil {
            let supportedNames = ["communityCode", "organizationCode", "code"]
            if let queryCode = components.queryItems?
                .first(where: { supportedNames.contains($0.name) })?.value {
                return normalized(queryCode)
            }
            if let last = components.path.split(separator: "/").last {
                return normalized(String(last))
            }
        }
        return normalized(trimmed)
    }

    private static func normalized(_ value: String) -> String? {
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty, result.count <= 100 else { return nil }
        return result.lowercased()
    }
}

public struct AccountCredentials: Equatable, Sendable {
    public static let minimumPasswordLength = 8

    public let email: String
    public let password: String
    public let passwordConfirmation: String?
    public let name: String?
    public let furigana: String?

    public init(
        email: String,
        password: String,
        passwordConfirmation: String? = nil,
        name: String? = nil,
        furigana: String? = nil
    ) {
        self.email = email
        self.password = password
        self.passwordConfirmation = passwordConfirmation
        self.name = name
        self.furigana = furigana
    }

    public func validationMessage() -> String? {
        if passwordConfirmation != nil,
           name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            return "名前を入力してください。"
        }
        if passwordConfirmation != nil,
           furigana?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            return "ふりがなを入力してください。"
        }
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = normalizedEmail.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1].contains(".") else {
            return "メールアドレスの形式を確認してください。"
        }
        guard password.count >= Self.minimumPasswordLength else {
            return "パスワードは8文字以上で入力してください。"
        }
        if let passwordConfirmation, password != passwordConfirmation {
            return "確認用パスワードが一致しません。"
        }
        return nil
    }
}
