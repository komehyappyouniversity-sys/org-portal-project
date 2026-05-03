//
//  AdminMemberPostStore.swift
//  ictnagaoka-admin
//
//  Created by OpenAI on 2026/04/20.
//

import Foundation
import Combine
import FirebaseFirestore

struct AdminMemberPostReplyItem: Identifiable, Equatable {
    let id: String
    let body: String
    let createdAt: Date?
    let createdBy: String
    let createdByName: String?

    var isFromAdmin: Bool {
        createdBy == "admin"
    }
}

struct AdminMemberPostItem: Identifiable, Equatable {
    let id: String
    let memberUid: String
    let memberName: String

    var title: String
    var body: String
    var status: String

    var createdAt: Date?
    var updatedAt: Date?

    var memberHasReadReply: Bool
    var replyCount: Int

    var replies: [AdminMemberPostReplyItem] = []

    var hasReply: Bool {
        replyCount > 0 || !replies.isEmpty
    }
}

@MainActor
final class AdminMemberPostStore: ObservableObject {
    @Published var posts: [AdminMemberPostItem] = []
    @Published var replies: [AdminMemberPostReplyItem] = []

    @Published var isLoading: Bool = false
    @Published var isRepliesLoading: Bool = false
    @Published var isSendingReply: Bool = false
    @Published var errorMessage: String = ""

    private let db = Firestore.firestore()

    private var postsListener: ListenerRegistration?
    private var repliesListener: ListenerRegistration?

    deinit {
        postsListener?.remove()
        repliesListener?.remove()
    }

    // MARK: - 投稿一覧監視

    func startListeningPosts(organizationId: String) {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            posts = []
            errorMessage = "organizationId が空です。"
            return
        }

        postsListener?.remove()
        isLoading = true
        errorMessage = ""

        postsListener = db.collection("organizations")
            .document(orgId)
            .collection("memberPosts")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                Task { @MainActor in
                    if let error {
                        self.isLoading = false
                        self.errorMessage = "会員投稿一覧の読み込みに失敗しました: \(error.localizedDescription)"
                        self.posts = []
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        self.isLoading = false
                        self.posts = []
                        return
                    }

                    self.posts = documents.map { self.makePostItem(from: $0) }
                    self.isLoading = false
                    self.errorMessage = ""
                }
            }
    }

    // MARK: - 返信一覧監視

    func startListeningReplies(
        organizationId: String,
        postId: String
    ) {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPostId = postId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty, !trimmedPostId.isEmpty else {
            replies = []
            errorMessage = "organizationId または postId が空です。"
            return
        }

        repliesListener?.remove()
        isRepliesLoading = true
        errorMessage = ""

        repliesListener = db.collection("organizations")
            .document(orgId)
            .collection("memberPosts")
            .document(trimmedPostId)
            .collection("replies")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                Task { @MainActor in
                    if let error {
                        self.isRepliesLoading = false
                        self.errorMessage = "返信履歴の読み込みに失敗しました: \(error.localizedDescription)"
                        self.replies = []
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        self.isRepliesLoading = false
                        self.replies = []
                        return
                    }

                    let newReplies = documents.map { self.makeReplyItem(from: $0) }
                    self.replies = newReplies
                    self.reflectRepliesLocally(postId: trimmedPostId, replies: newReplies)

                    self.isRepliesLoading = false
                    self.errorMessage = ""
                }
            }
    }

    func stopListeningReplies() {
        repliesListener?.remove()
        repliesListener = nil
        replies = []
        isRepliesLoading = false
    }

    // MARK: - 返信送信（履歴保存）

    func sendReply(
        organizationId: String,
        postId: String,
        replyBody: String,
        adminName: String = "管理者"
    ) async throws {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPostId = postId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplyBody = replyBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAdminName = adminName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "管理者"
            : adminName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty, !trimmedPostId.isEmpty else {
            throw NSError(
                domain: "AdminMemberPostStore",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "organizationId または postId が空です。"]
            )
        }

        guard !trimmedReplyBody.isEmpty else {
            throw NSError(
                domain: "AdminMemberPostStore",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "返信内容を入力してください。"]
            )
        }

        isSendingReply = true
        errorMessage = ""

        let postRef = db.collection("organizations")
            .document(orgId)
            .collection("memberPosts")
            .document(trimmedPostId)

        let replyRef = postRef.collection("replies").document()

        let batch = db.batch()

        batch.setData([
            "body": trimmedReplyBody,
            "createdAt": FieldValue.serverTimestamp(),
            "createdBy": "admin",
            "createdByName": trimmedAdminName
        ], forDocument: replyRef)

        batch.setData([
            "memberHasReadReply": false,
            "status": "new",
            "replyCount": FieldValue.increment(Int64(1)),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: postRef, merge: true)

        do {
            try await batch.commit()

            print("✅ 管理者返信保存成功")
            print("postId:", trimmedPostId)
            print("replyId:", replyRef.documentID)

        } catch {
            errorMessage = "返信の保存に失敗しました: \(error.localizedDescription)"
            isSendingReply = false
            throw error
        }

        isSendingReply = false
    }

    // MARK: - 状態変更

    func updateStatus(
        organizationId: String,
        postId: String,
        status: String
    ) async throws {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPostId = postId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty, !trimmedPostId.isEmpty, !trimmedStatus.isEmpty else { return }

        try await db.collection("organizations")
            .document(orgId)
            .collection("memberPosts")
            .document(trimmedPostId)
            .updateData([
                "status": trimmedStatus,
                "updatedAt": FieldValue.serverTimestamp()
            ])

        if let index = posts.firstIndex(where: { $0.id == trimmedPostId }) {
            posts[index].status = trimmedStatus
        }
    }

    // MARK: - ローカル反映

    private func reflectRepliesLocally(
        postId: String,
        replies: [AdminMemberPostReplyItem]
    ) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        posts[index].replies = replies
        posts[index].replyCount = replies.count
    }

    // MARK: - Firestore -> Model

    private func makePostItem(from document: DocumentSnapshot) -> AdminMemberPostItem {
        let data = document.data() ?? [:]

        return AdminMemberPostItem(
            id: document.documentID,
            memberUid: data["memberUid"] as? String ?? "",
            memberName: data["memberName"] as? String ?? "",
            title: data["title"] as? String ?? "",
            body: data["body"] as? String ?? data["messageBody"] as? String ?? "",
            status: data["status"] as? String ?? "new",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue(),
            memberHasReadReply: data["memberHasReadReply"] as? Bool ?? true,
            replyCount: data["replyCount"] as? Int ?? 0,
            replies: []
        )
    }

    private func makeReplyItem(from document: DocumentSnapshot) -> AdminMemberPostReplyItem {
        let data = document.data() ?? [:]

        return AdminMemberPostReplyItem(
            id: document.documentID,
            body: data["body"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            createdBy: data["createdBy"] as? String ?? "",
            createdByName: data["createdByName"] as? String
        )
    }
}
