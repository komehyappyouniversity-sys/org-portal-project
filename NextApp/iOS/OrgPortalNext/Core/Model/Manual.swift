import Foundation

public struct Manual: Equatable, Codable, Sendable {
    public let id: String
    public let communityId: String?
    public let title: String
    public let body: String
    public let sortOrder: Int
    public let imageUrls: [String]
    public let pdfUrl: String?
    public let externalUrl: String?
    public let isPublished: Bool

    public init(
        id: String,
        communityId: String?,
        title: String,
        body: String,
        sortOrder: Int,
        imageUrls: [String] = [],
        pdfUrl: String? = nil,
        externalUrl: String? = nil,
        isPublished: Bool
    ) {
        self.id = id
        self.communityId = communityId
        self.title = title
        self.body = body
        self.sortOrder = sortOrder
        self.imageUrls = imageUrls
        self.pdfUrl = pdfUrl
        self.externalUrl = externalUrl
        self.isPublished = isPublished
    }

    public var listIdentity: String {
        "\(communityId ?? "shared"):\(id)"
    }
}
