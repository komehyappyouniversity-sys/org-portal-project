//
//  AdminMemberPostService.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/15.
//

import Foundation
import FirebaseFirestore

protocol AdminMemberPostServiceProtocol {
    func fetchPosts(organizationId: String) async throws -> [AdminMemberPostItem]

    func listenPosts(
        organizationId: String,
        onChange: @escaping (Result<[AdminMemberPostItem], Error>) -> Void
    ) -> ListenerRegistration

    func fetchPost(
        organizationId: String,
        postId: String
    ) async throws -> AdminMemberPostItem?

    func updateStatus(
        organizationId: String,
        postId: String,
        status: String
    ) async throws

    func updateAdminReply(
        organizationId: String,
        postId: String,
        adminReply: String
    ) async throws

    func deletePost(
        organizationId: String,
        postId: String
    ) async throws
}

final class AdminMemberPostService: AdminMemberPostServiceProtocol {
    private let db = Firestore.firestore()

    private func postsCollection(organizationId: String) -> CollectionReference {
        db.collection("organizations")
            .document(organizationId)
            .collection("memberPosts")
    }

    // MARK: - Fetch List

    func fetchPosts(organizationId: String) async throws -> [AdminMemberPostItem] {
        let snapshot = try await postsCollection(organizationId: organizationId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { makeItem(from: $0) }
    }

    // MARK: - Listen List

    func listenPosts(
        organizationId: String,
        onChange: @escaping (Result<[AdminMemberPostItem], Error>) -> Void
    ) -> ListenerRegistration {
        postsCollection(organizationId: organizationId)
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

                let items = snapshot.documents.compactMap { self.makeItem(from: $0) }
                onChange(.success(items))
            }
    }

    // MARK: - Fetch One

    func fetchPost(
        organizationId: String,
        postId: String
    ) async throws -> AdminMemberPostItem? {
        let document = try await postsCollection(organizationId: organizationId)
            .document(postId)
            .getDocument()

        guard document.exists else { return nil }
        return makeItem(from: document)
    }

    // MARK: - Update Status

    func updateStatus(
        organizationId: String,
        postId: String,
        status: String
    ) async throws {
        try await postsCollection(organizationId: organizationId)
            .document(postId)
            .updateData([
                "status": status,
                "updatedAt": Timestamp(date: Date())
            ])
    }

    // MARK: - Update Reply
    // 返信保存時に memberHasReadReply = false を必ず戻す
    // これで会員側に未読バッジが立つ

    func updateAdminReply(
        organizationId: String,
        postId: String,
        adminReply: String
    ) async throws {
        let trimmedReply = adminReply.trimmingCharacters(in: .whitespacesAndNewlines)

        try await postsCollection(organizationId: organizationId)
            .document(postId)
            .updateData([
                "adminReply": trimmedReply,
                "memberHasReadReply": false,
                "updatedAt": Timestamp(date: Date())
            ])
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

    // MARK: - Mapping

    private func makeItem(from document: DocumentSnapshot) -> AdminMemberPostItem? {
        let data = document.data() ?? [:]

        let memberUid = data["memberUid"] as? String ?? ""
        let memberName = data["memberName"] as? String ?? "お名前未設定"

        let title = data["title"] as? String ?? ""
        let body = data["body"] as? String ?? ""

        let imageURLs = data["imageURLs"] as? [String] ?? []
        let pdfURL = data["pdfURL"] as? String

        let status = data["status"] as? String ?? "new"
        let adminReply = data["adminReply"] as? String

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()

        return AdminMemberPostItem(
            id: document.documentID,
            memberUid: memberUid,
            memberName: memberName,
            title: title,
            body: body,
            imageURLs: imageURLs,
            pdfURL: pdfURL,
            status: status,
            adminReply: adminReply,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
