//
//  MemberPostService.swift
//  ictnagaoka
//
//  Created by 根津浩 on 2026/04/16.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

protocol MemberPostServiceProtocol {
    func fetchMyPosts(
        organizationId: String,
        memberUid: String
    ) async throws -> [MemberPostItem]

    func listenMyPosts(
        organizationId: String,
        memberUid: String,
        onChange: @escaping (Result<[MemberPostItem], Error>) -> Void
    ) -> ListenerRegistration

    func fetchPost(
        organizationId: String,
        postId: String
    ) async throws -> MemberPostItem?

    func createPost(
        organizationId: String,
        memberUid: String,
        memberName: String,
        title: String,
        body: String,
        imageURLs: [String],
        pdfURL: String?
    ) async throws

    func updatePost(
        organizationId: String,
        postId: String,
        title: String,
        body: String,
        imageURLs: [String],
        pdfURL: String?
    ) async throws

    func deletePost(
        organizationId: String,
        postId: String
    ) async throws

    func markReplyAsRead(
        organizationId: String,
        postId: String
    ) async throws
}

final class MemberPostService: MemberPostServiceProtocol {
    private let db = Firestore.firestore()

    private func postsCollection(organizationId: String) -> CollectionReference {
        db.collection("organizations")
            .document(organizationId)
            .collection("memberPosts")
    }

    // MARK: - Fetch My Posts

    func fetchMyPosts(
        organizationId: String,
        memberUid: String
    ) async throws -> [MemberPostItem] {
        let snapshot = try await postsCollection(organizationId: organizationId)
            .whereField("memberUid", isEqualTo: memberUid)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { MemberPostItem(document: $0) }
    }

    // MARK: - Listen My Posts

    func listenMyPosts(
        organizationId: String,
        memberUid: String,
        onChange: @escaping (Result<[MemberPostItem], Error>) -> Void
    ) -> ListenerRegistration {
        postsCollection(organizationId: organizationId)
            .whereField("memberUid", isEqualTo: memberUid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                guard let snapshot else {
                    onChange(.success([]))
                    return
                }

                let items = snapshot.documents.compactMap { MemberPostItem(document: $0) }
                onChange(.success(items))
            }
    }

    // MARK: - Fetch One

    func fetchPost(
        organizationId: String,
        postId: String
    ) async throws -> MemberPostItem? {
        let document = try await postsCollection(organizationId: organizationId)
            .document(postId)
            .getDocument()

        guard document.exists else { return nil }
        return MemberPostItem(document: document)
    }

    // MARK: - Create

    func createPost(
        organizationId: String,
        memberUid: String,
        memberName: String,
        title: String,
        body: String,
        imageURLs: [String],
        pdfURL: String?
    ) async throws {
        let trimmedOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMemberUid = memberUid.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMemberName = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        let now = Timestamp(date: Date())

        var data: [String: Any] = [
            "organizationId": trimmedOrganizationId,
            "memberUid": trimmedMemberUid,
            "memberName": trimmedMemberName,
            "title": trimmedTitle,
            "body": trimmedBody,
            "imageURLs": imageURLs,
            "status": "new",
            "adminReply": "",
            "memberHasReadReply": true,
            "createdAt": now,
            "updatedAt": now
        ]

        if let pdfURL, !pdfURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["pdfURL"] = pdfURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        print("🟡 createPost 開始")
        print("🟡 organizationId:", trimmedOrganizationId)
        print("🟡 memberUid:", trimmedMemberUid)
        print("🟡 memberName:", trimmedMemberName)
        print("🟡 title:", trimmedTitle)
        print("🟡 body:", trimmedBody)

        let ref = try await postsCollection(organizationId: trimmedOrganizationId)
            .addDocument(data: data)

        print("✅ 会員投稿保存成功:", ref.documentID)
        print("✅ 保存先: organizations/\(trimmedOrganizationId)/memberPosts/\(ref.documentID)")
    }

    // MARK: - Update

    func updatePost(
        organizationId: String,
        postId: String,
        title: String,
        body: String,
        imageURLs: [String],
        pdfURL: String?
    ) async throws {
        var data: [String: Any] = [
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "body": body.trimmingCharacters(in: .whitespacesAndNewlines),
            "imageURLs": imageURLs,
            "updatedAt": Timestamp(date: Date())
        ]

        if let pdfURL, !pdfURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["pdfURL"] = pdfURL
        } else {
            data["pdfURL"] = FieldValue.delete()
        }

        try await postsCollection(organizationId: organizationId)
            .document(postId)
            .updateData(data)
    }

    // MARK: - Delete

    func deletePost(
        organizationId: String,
        postId: String
    ) async throws {
        try await postsCollection(organizationId: organizationId)
            .document(postId)
            .delete()
    }

    // MARK: - Reply Read

    func markReplyAsRead(
        organizationId: String,
        postId: String
    ) async throws {
        try await postsCollection(organizationId: organizationId)
            .document(postId)
            .updateData([
                "memberHasReadReply": true,
                "updatedAt": Timestamp(date: Date())
            ])
    }
}
