//
//  AdminVideoItem.swift
//  ictnagaoka-admin
//

import Foundation
import FirebaseFirestore

struct AdminVideoItem: Identifiable, Equatable {
    let id: String
    let title: String
    let url: String
    let thumbnailUrl: String
    let vimeoId: String
    let isPublished: Bool
    let isPremium: Bool
    let createdAt: Date?

    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]

        guard let title = data["title"] as? String else {
            return nil
        }

        self.id = document.documentID
        self.title = title
        self.url = data["url"] as? String ?? ""
        self.thumbnailUrl = data["thumbnailUrl"] as? String ?? ""
        self.vimeoId = data["vimeoId"] as? String ?? ""
        self.isPublished = data["isPublished"] as? Bool ?? false
        self.isPremium = data["isPremium"] as? Bool ?? false

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = nil
        }
    }
}
