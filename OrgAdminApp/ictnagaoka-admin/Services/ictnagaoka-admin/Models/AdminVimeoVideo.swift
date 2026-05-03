import Foundation

struct AdminVimeoVideo: Identifiable, Equatable {
    let id: String
    let uri: String
    let vimeoVideoId: String
    let name: String
    let description: String
    let duration: Int
    let link: String
    let embedHtml: String
    let privacyView: String
    let privacyEmbed: String
    let thumbnailUrl: String
    let createdTime: String
    let modifiedTime: String
}

struct AdminRegisteredVideo: Identifiable, Equatable {
    var id: String { vimeoVideoId }

    let vimeoVideoId: String
    let category: String
    let isPremium: Bool
    let isPublished: Bool
}
