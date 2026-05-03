//
//  MemberPost.swift
//  blog.k100
//
//  Created by 根津浩 on 2026/04/16.
//

//
//  MemberPost.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/15.
//

import Foundation
import FirebaseFirestore

struct MemberPost: Identifiable, Hashable {

    let id: String

    let memberUid: String
    let memberName: String

    let title: String
    let body: String

    let imageURLs: [String]
    let pdfURL: String?

    let createdAt: Date?
    let updatedAt: Date?

    // MARK: - Init

    init(
        id: String,
        memberUid: String,
        memberName: String,
        title: String,
        body: String,
        imageURLs: [String] = [],
        pdfURL: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.memberUid = memberUid
        self.memberName = memberName
        self.title = title
        self.body = body
        self.imageURLs = imageURLs
        self.pdfURL = pdfURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Firestore → Model

    static func from(document: DocumentSnapshot) -> MemberPost? {
        let data = document.data() ?? [:]

        return MemberPost(
            id: document.documentID,
            memberUid: data["memberUid"] as? String ?? "",
            memberName: data["memberName"] as? String ?? "不明",
            title: data["title"] as? String ?? "",
            body: data["body"] as? String ?? "",
            imageURLs: data["imageURLs"] as? [String] ?? [],
            pdfURL: data["pdfURL"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }

    // MARK: - Model → Firestore

    func toDictionary() -> [String: Any] {
        return [
            "memberUid": memberUid,
            "memberName": memberName,
            "title": title,
            "body": body,
            "imageURLs": imageURLs,
            "pdfURL": pdfURL as Any,
            "createdAt": createdAt != nil ? Timestamp(date: createdAt!) : FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

