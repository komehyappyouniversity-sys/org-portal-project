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

        listener = db.collection("organizations")
            .document(orgId)
            .collection("videos")
            .whereField("isPublished", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                Task { @MainActor in
                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        self.videos = []
                        print("❌ MemberVideoStore error:", error.localizedDescription)
                        return
                    }

                    self.videos = snapshot?.documents.compactMap {
                        MemberVideoItem(document: $0)
                    } ?? []

                    print("✅ 動画読み込み成功:", self.videos.count)
                }
            }
    }
}
