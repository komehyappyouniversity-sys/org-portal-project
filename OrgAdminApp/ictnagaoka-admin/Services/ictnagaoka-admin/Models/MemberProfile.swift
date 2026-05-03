//
//  MemberProfile.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/16.
//

//
//  MemberProfile.swift
//  ictnagaoka-admin
//
//  Created by OpenAI on 2026/04/16.
//

import Foundation
import FirebaseFirestore

struct MemberProfile: Identifiable, Hashable {
    let id: String
    let uid: String
    let name: String
    let status: String
    let organizationId: String
    let category: String?

    var isApproved: Bool {
        status == "approved"
    }

    init(
        id: String,
        uid: String,
        name: String,
        status: String,
        organizationId: String,
        category: String? = nil
    ) {
        self.id = id
        self.uid = uid
        self.name = name
        self.status = status
        self.organizationId = organizationId
        self.category = category
    }

    static func from(document: DocumentSnapshot) -> MemberProfile? {
        let data = document.data() ?? [:]

        return MemberProfile(
            id: document.documentID,
            uid: data["uid"] as? String ?? "",
            name: data["name"] as? String ?? "",
            status: data["status"] as? String ?? "",
            organizationId: data["organizationId"] as? String ?? "",
            category: data["category"] as? String
        )
    }
}
