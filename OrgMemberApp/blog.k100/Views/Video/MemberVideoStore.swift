//
//  MemberVideoStore.swift
//  blog.k100
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class MemberVideoStore: ObservableObject {

    @Published var videos: [MemberVideoItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(organizationId: String) {

        let orgId = organizationId.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !orgId.isEmpty else {
            errorMessage = "organizationId が空です。"
            videos = []
            return
        }

        listener?.remove()
        isLoading = true
        errorMessage = ""

        listener = Firestore.firestore()
            .collection("organizations")
            .document(orgId)
            .collection("videos")
            .whereField("isPublished", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in

                guard let self else {
                    return
                }

                Task { @MainActor in

                    self.isLoading = false

                    if let error {

                        self.errorMessage = error.localizedDescription
                        self.videos = []

                        print(
                            "❌ MemberVideoStore error:",
                            error.localizedDescription
                        )

                        return
                    }

                    let loadedVideos: [MemberVideoItem] =
                        snapshot?.documents.compactMap { document in
                            MemberVideoItem(document: document)
                        } ?? []

                    self.videos = loadedVideos

                    print("✅ 動画読み込み成功:", self.videos.count)
                }
            }
    }
}
