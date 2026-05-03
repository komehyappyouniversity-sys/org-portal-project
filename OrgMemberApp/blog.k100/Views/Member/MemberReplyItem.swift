//
//  MemberReplyItem.swift
//  ictnagaoka
//
//  Created by OpenAI on 2026/04/16.
//

import Foundation
import FirebaseFirestore

struct MemberReplyItem: Identifiable, Hashable {
    let id: String
    let senderType: String
    let text: String
    let memberHasRead: Bool
    let createdAt: Date?
    let updatedAt: Date?

    var isAdminReply: Bool {
        senderType == "admin"
    }

    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]

        guard
            let senderType = data["senderType"] as? String,
            let text = data["text"] as? String
        else {
            return nil
        }

        self.id = document.documentID
        self.senderType = senderType
        self.text = text
        self.memberHasRead = data["memberHasRead"] as? Bool ?? false
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
    }
}
