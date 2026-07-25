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
