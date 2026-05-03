//
//  AdminVideoStore.swift
//  ictnagaoka-admin
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class AdminVideoStore: ObservableObject {
    @Published var videos: [AdminVideoItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var successMessage: String = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(organizationId: String) {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            errorMessage = "organizationId が空です。"
            videos = []
            return
        }

        listener?.remove()
        isLoading = true
        errorMessage = ""
        successMessage = ""

        listener = db.collection("organizations")
            .document(orgId)
            .collection("videos")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                Task { @MainActor in
                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        self.videos = []
                        print("❌ AdminVideoStore listen error:", error.localizedDescription)
                        return
                    }

                    self.videos = snapshot?.documents.compactMap {
                        AdminVideoItem(document: $0)
                    } ?? []

                    print("✅ videos 読み込み成功:", self.videos.count)
                }
            }
    }

    func addVideo(
        organizationId: String,
        title: String,
        url: String,
        isPublished: Bool,
        isPremium: Bool
    ) async {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            errorMessage = "organizationId が空です。"
            return
        }

        guard !trimmedTitle.isEmpty else {
            errorMessage = "タイトルを入力してください。"
            return
        }

        guard !trimmedUrl.isEmpty else {
            errorMessage = "動画URLを入力してください。"
            return
        }

        guard URL(string: trimmedUrl) != nil else {
            errorMessage = "正しい動画URLを入力してください。"
            return
        }

        isLoading = true
        errorMessage = ""
        successMessage = ""

        do {
            let data: [String: Any] = [
                "title": trimmedTitle,
                "url": trimmedUrl,
                "thumbnailUrl": "",
                "vimeoId": "",
                "isPublished": isPublished,
                "isPremium": isPremium,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]

            try await db.collection("organizations")
                .document(orgId)
                .collection("videos")
                .addDocument(data: data)

            successMessage = "動画を登録しました。"
            print("✅ 動画登録成功:", trimmedTitle)
        } catch {
            errorMessage = error.localizedDescription
            print("❌ 動画登録失敗:", error.localizedDescription)
        }

        isLoading = false
    }

    func updatePublished(
        organizationId: String,
        videoId: String,
        isPublished: Bool
    ) async {
        await updateVideoField(
            organizationId: organizationId,
            videoId: videoId,
            data: [
                "isPublished": isPublished,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            successText: isPublished ? "公開にしました。" : "非公開にしました。"
        )
    }

    func updatePremium(
        organizationId: String,
        videoId: String,
        isPremium: Bool
    ) async {
        await updateVideoField(
            organizationId: organizationId,
            videoId: videoId,
            data: [
                "isPremium": isPremium,
                "updatedAt": FieldValue.serverTimestamp()
            ],
            successText: isPremium ? "有料にしました。" : "無料にしました。"
        )
    }

    func deleteVideo(
        organizationId: String,
        videoId: String
    ) async {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            errorMessage = "organizationId が空です。"
            return
        }

        guard !videoId.isEmpty else {
            errorMessage = "videoId が空です。"
            return
        }

        errorMessage = ""
        successMessage = ""

        do {
            try await db.collection("organizations")
                .document(orgId)
                .collection("videos")
                .document(videoId)
                .delete()

            successMessage = "動画を削除しました。"
            print("✅ 動画削除成功:", videoId)
        } catch {
            errorMessage = error.localizedDescription
            print("❌ 動画削除失敗:", error.localizedDescription)
        }
    }

    private func updateVideoField(
        organizationId: String,
        videoId: String,
        data: [String: Any],
        successText: String
    ) async {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            errorMessage = "organizationId が空です。"
            return
        }

        guard !videoId.isEmpty else {
            errorMessage = "videoId が空です。"
            return
        }

        errorMessage = ""
        successMessage = ""

        do {
            try await db.collection("organizations")
                .document(orgId)
                .collection("videos")
                .document(videoId)
                .updateData(data)

            successMessage = successText
            print("✅ 動画更新成功:", videoId)
        } catch {
            errorMessage = error.localizedDescription
            print("❌ 動画更新失敗:", error.localizedDescription)
        }
    }
}
