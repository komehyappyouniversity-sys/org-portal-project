import Foundation
import FirebaseFirestore

struct VideoItem: Identifiable {
    let id: String
    let title: String
    let url: String
    let isPremium: Bool

    init?(doc: DocumentSnapshot) {
        let data = doc.data() ?? [:]

        guard
            let title = data["title"] as? String,
            let url = data["url"] as? String
        else { return nil }

        self.id = doc.documentID
        self.title = title
        self.url = url
        self.isPremium = data["isPremium"] as? Bool ?? false
    }
}
