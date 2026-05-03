//
//  MessageItem.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/15.
//

import Foundation
import FirebaseFirestore

struct MessageItem: Identifiable, Hashable {
    let id: String

    let title: String
    let body: String

    let createdAt: Date?
    let updatedAt: Date?

    let isBroadcast: Bool
    let categoryTargets: [String]
    let targetMemberUids: [String]
    let isReadBy: [String]

    init(
        id: String,
        title: String,
        body: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        isBroadcast: Bool = false,
        categoryTargets: [String] = [],
        targetMemberUids: [String] = [],
        isReadBy: [String] = []
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isBroadcast = isBroadcast
        self.categoryTargets = categoryTargets
        self.targetMemberUids = targetMemberUids
        self.isReadBy = isReadBy
    }

    static func from(document: DocumentSnapshot) -> MessageItem? {
        let data = document.data() ?? [:]

        return MessageItem(
            id: document.documentID,
            title: data["title"] as? String ?? "",
            body: data["body"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue(),
            isBroadcast: data["isBroadcast"] as? Bool ?? false,
            categoryTargets: data["categoryTargets"] as? [String] ?? [],
            targetMemberUids: data["targetMemberUids"] as? [String] ?? [],
            isReadBy: data["isReadBy"] as? [String] ?? []
        )
    }
}
