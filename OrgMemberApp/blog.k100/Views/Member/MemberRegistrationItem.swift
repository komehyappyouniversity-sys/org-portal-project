//
//  MemberRegistrationItem.swift
//  blog.k100
//
//  Created by 根津浩 on 2026/04/16.
//

//
//  MemberRegistrationItem.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/15.
//

import Foundation
import FirebaseFirestore

struct MemberRegistrationItem: Identifiable, Hashable {
    let id: String
    let uid: String
    let organizationId: String
    let name: String
    let phone: String
    let status: String
    let createdAt: Date?

    init(
        id: String,
        uid: String,
        organizationId: String,
        name: String,
        phone: String,
        status: String,
        createdAt: Date?
    ) {
        self.id = id
        self.uid = uid
        self.organizationId = organizationId
        self.name = name
        self.phone = phone
        self.status = status
        self.createdAt = createdAt
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.uid = data["uid"] as? String ?? ""
        self.organizationId = data["organizationId"] as? String ?? ""
        self.name = data["name"] as? String ?? ""
        self.phone = data["phone"] as? String ?? ""
        self.status = data["status"] as? String ?? "pending"

        if let ts = data["createdAt"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = nil
        }
    }
}

