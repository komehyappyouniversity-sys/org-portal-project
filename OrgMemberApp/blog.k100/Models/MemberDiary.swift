import Foundation
import FirebaseFirestore

struct MemberDiary: Identifiable {
    let id: String
    let title: String
    let body: String
    let mood: String
    let imageURLs: [String]
    let createdAt: Date
    let updatedAt: Date

    init(
        id: String,
        title: String,
        body: String,
        mood: String,
        imageURLs: [String],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.mood = mood
        self.imageURLs = imageURLs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.title = data["title"] as? String ?? ""
        self.body = data["body"] as? String ?? ""
        self.mood = data["mood"] as? String ?? "普通"
        self.imageURLs = data["imageURLs"] as? [String] ?? []

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }

        if let timestamp = data["updatedAt"] as? Timestamp {
            self.updatedAt = timestamp.dateValue()
        } else {
            self.updatedAt = Date()
        }
    }
}
