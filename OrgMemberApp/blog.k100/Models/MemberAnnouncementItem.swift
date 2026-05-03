//
//  MemberAnnouncementItem.swift
//  ictnagaoka
//
//  Created by 根津浩 on 2026/04/19.
//

import Foundation
import FirebaseFirestore

struct MemberAnnouncementItem: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let organizationId: String
    let createdBy: String
    let createdAt: Date?
    let updatedAt: Date?
    let isPublished: Bool

    init(
        id: String,
        title: String,
        body: String,
        organizationId: String,
        createdBy: String,
        createdAt: Date?,
        updatedAt: Date?,
        isPublished: Bool
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.organizationId = organizationId
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPublished = isPublished
    }

    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]

        let title = (data["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body = (data["body"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let organizationId = data["organizationId"] as? String ?? ""
        let createdBy = data["createdBy"] as? String ?? ""
        let isPublished = data["isPublished"] as? Bool ?? false

        guard !title.isEmpty, !body.isEmpty else { return nil }
        guard isPublished == true else { return nil }

        self.id = document.documentID
        self.title = title
        self.body = body
        self.organizationId = organizationId
        self.createdBy = createdBy
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        self.isPublished = isPublished
    }
}
