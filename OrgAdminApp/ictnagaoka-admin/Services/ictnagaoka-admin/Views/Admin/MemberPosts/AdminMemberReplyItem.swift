//
//  AdminMemberReplyItem.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/16.
//

//
//  AdminMemberReplyItem.swift
//  ictnagaoka-admin
//
//  Created by OpenAI on 2026/04/16.
//

import Foundation
import FirebaseFirestore

struct AdminMemberReplyItem: Identifiable, Hashable {
    let id: String
    let senderType: String
    let text: String
    let organizationId: String
    let memberUid: String
    let memberHasRead: Bool
    let createdAt: Date?
    let updatedAt: Date?

    var isAdminReply: Bool {
        senderType == "admin"
    }

    init(
        id: String,
        senderType: String,
        text: String,
        organizationId: String,
        memberUid: String,
        memberHasRead: Bool,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.senderType = senderType
        self.text = text
        self.organizationId = organizationId
        self.memberUid = memberUid
        self.memberHasRead = memberHasRead
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]

        guard
            let senderType = data["senderType"] as? String,
            let text = data["text"] as? String,
            let organizationId = data["organizationId"] as? String,
            let memberUid = data["memberUid"] as? String
        else {
            return nil
        }

        self.id = document.documentID
        self.senderType = senderType
        self.text = text
        self.organizationId = organizationId
        self.memberUid = memberUid
        self.memberHasRead = data["memberHasRead"] as? Bool ?? false
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
    }
}
