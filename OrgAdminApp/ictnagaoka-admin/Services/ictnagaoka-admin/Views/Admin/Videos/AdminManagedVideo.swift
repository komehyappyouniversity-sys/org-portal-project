import Foundation
import FirebaseFirestore

struct AdminManagedVideo: Identifiable, Codable {
    @DocumentID var id: String?

    var title: String
    var description: String
    var vimeoVideoId: String
    var thumbnailUrl: String
    var videoUrl: String

    var isPublished: Bool
    var isMembersOnly: Bool
    var isPremium: Bool

    var sortOrder: Int

    var createdAt: Timestamp?
    var updatedAt: Timestamp?

    init(
        id: String? = nil,
        title: String = "",
        description: String = "",
        vimeoVideoId: String = "",
        thumbnailUrl: String = "",
        videoUrl: String = "",
        isPublished: Bool = false,
        isMembersOnly: Bool = false,
        isPremium: Bool = false,
        sortOrder: Int = 0,
        createdAt: Timestamp? = nil,
        updatedAt: Timestamp? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.vimeoVideoId = vimeoVideoId
        self.thumbnailUrl = thumbnailUrl
        self.videoUrl = videoUrl
        self.isPublished = isPublished
        self.isMembersOnly = isMembersOnly
        self.isPremium = isPremium
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
