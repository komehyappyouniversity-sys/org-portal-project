//
//  AdminRequestItem.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/16.
//

import Foundation
import FirebaseFirestore

struct AdminRequestItem: Identifiable, Hashable {
    let id: String

    let organizationId: String

    let uid: String
    let memberId: String
    let name: String
    let furigana: String
    let phone: String
    let email: String
    let address: String
    let note: String

    let status: String
    let createdAt: Date?
    let updatedAt: Date?

    init(
        id: String,
        organizationId: String,
        uid: String,
        memberId: String,
        name: String,
        furigana: String,
        phone: String,
        email: String,
        address: String,
        note: String,
        status: String,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.organizationId = organizationId
        self.uid = uid
        self.memberId = memberId
        self.name = name
        self.furigana = furigana
        self.phone = phone
        self.email = email
        self.address = address
        self.note = note
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init?(document: DocumentSnapshot, organizationId: String) {
        let data = document.data() ?? [:]

        self.id = document.documentID
        self.organizationId = organizationId

        self.uid = data["uid"] as? String ?? ""
        self.memberId = data["memberId"] as? String ?? ""
        self.name = data["name"] as? String ?? ""
        self.furigana = data["furigana"] as? String ?? ""
        self.phone = data["phone"] as? String ?? ""
        self.email = data["email"] as? String ?? ""
        self.address = data["address"] as? String ?? ""
        self.note = data["note"] as? String ?? ""
        self.status = data["status"] as? String ?? "pending"
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
    }
}
