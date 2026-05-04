import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import UIKit

@MainActor
final class MemberMessageStore: ObservableObject {
    @Published var items: [MemberMessageItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var unreadCount = 0

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(
        organizationId: String,
        messageReadBaselineAt: Date? = nil,
        mode: String = "public"
    ) {
        let uid = Auth.auth().currentUser?.uid ?? ""

        print("========== MemberMessageStore startListening ==========")
        print("mode:", mode)

        listener?.remove()
        isLoading = true
        errorMessage = nil

        db.collection("organizations")
            .document(organizationId)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        print("❌ error:", error.localizedDescription)
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        self.items = []
                        self.unreadCount = 0
                        self.updateBadge()
                        return
                    }

                    let loadedItems = documents.compactMap { doc in
                        self.makeItem(
                            from: doc,
                            uid: uid,
                            mode: mode,
                            baseline: messageReadBaselineAt
                        )
                    }

                    self.items = loadedItems
                    self.unreadCount = loadedItems.filter { !$0.isRead }.count

                    self.updateBadge()

                    print("✅ 件数:", loadedItems.count)
                    print("🔴 未読:", self.unreadCount)
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func markAsRead(messageId: String, organizationId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("organizations")
                .document(organizationId)
                .collection("messages")
                .document(messageId)
                .updateData([
                    "isReadBy": FieldValue.arrayUnion([uid])
                ])
        } catch {
            print("❌ 既読更新失敗:", error.localizedDescription)
        }
    }

    private func makeItem(
        from document: QueryDocumentSnapshot,
        uid: String,
        mode: String,
        baseline: Date?
    ) -> MemberMessageItem? {

        let data = document.data()
        let messageType = data["messageType"] as? String ?? ""

        // 🔵 未会員
        if mode == "public" {
            guard messageType == "publicAnnouncement" else { return nil }
        }

        // 🟢 会員
        if mode == "member" {
            guard messageType == "publicAnnouncement" || messageType == "memberMessage" else {
                return nil
            }
        }

        let title = data["title"] as? String ?? ""
        let body = data["body"] as? String ?? ""

        let createdAt: Date = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        let isReadBy = data["isReadBy"] as? [String] ?? []

        let isRead =
            isReadBy.contains(uid) ||
            (baseline != nil && createdAt <= baseline!)

        return MemberMessageItem(
            id: document.documentID,
            title: title,
            body: body,
            createdAt: createdAt,
            isRead: isRead
        )
    }

    // 🔴 ここが今回のポイント
    private func updateBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = self.unreadCount
            print("🔴 バッジ更新:", self.unreadCount)
        }
    }
}
