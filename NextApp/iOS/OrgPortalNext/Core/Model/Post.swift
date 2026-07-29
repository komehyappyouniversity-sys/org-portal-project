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
