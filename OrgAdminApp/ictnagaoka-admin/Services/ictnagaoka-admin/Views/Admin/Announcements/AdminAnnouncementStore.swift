//
//  AdminAnnouncementStore.swift
//  ictnagaoka-admin
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AdminAnnouncementStore: ObservableObject {
    @Published var title: String = ""
    @Published var body: String = ""

    @Published var isSaving: Bool = false
    @Published var errorMessage: String = ""
    @Published var successMessage: String = ""

    private let db = Firestore.firestore()

    func sendAnnouncement(organizationId: String) async -> Bool {
        let trimmedOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        print("========== AdminAnnouncementStore sendAnnouncement START ==========")
        print("save path: organizations/\(trimmedOrganizationId)/messages")
        print("title:", trimmedTitle)
        print("body count:", trimmedBody.count)

        guard !trimmedOrganizationId.isEmpty else {
            errorMessage = "organizationId が空です。"
            successMessage = ""
            return false
        }

        guard !trimmedTitle.isEmpty else {
            errorMessage = "タイトルを入力してください。"
            successMessage = ""
            return false
        }

        guard !trimmedBody.isEmpty else {
            errorMessage = "本文を入力してください。"
            successMessage = ""
            return false
        }

        isSaving = true
        errorMessage = ""
        successMessage = ""

        let createdBy = Auth.auth().currentUser?.uid ?? ""

        let data: [String: Any] = [
            "organizationId": trimmedOrganizationId,
            "title": trimmedTitle,
            "body": trimmedBody,
            "createdBy": createdBy,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),

            // messages 統一用
            "visibility": "public",
            "deliveryType": "公開お知らせ",
            "isBroadcast": true,
            "isPublished": true,

            // 既読・通知用
            "isReadBy": [],
            "notificationStatus": "pending",
            "notifiedCount": 0
        ]

        do {
            let ref = try await db.collection("organizations")
                .document(trimmedOrganizationId)
                .collection("messages")
                .addDocument(data: data)

            print("✅ public announcement saved to messages")
            print("documentId:", ref.documentID)

            title = ""
            body = ""
            isSaving = false
            errorMessage = ""
            successMessage = "公開お知らせを送信しました。"

            print("========== AdminAnnouncementStore sendAnnouncement END ==========")
            return true

        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
            successMessage = ""

            print("❌ public announcement save error:", error.localizedDescription)
            print("========== AdminAnnouncementStore sendAnnouncement END ==========")
            return false
        }
    }
}
