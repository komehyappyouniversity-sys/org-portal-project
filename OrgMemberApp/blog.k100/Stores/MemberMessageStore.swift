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
        let safeOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let uid = Auth.auth().currentUser?.uid ?? ""

        print("========== MemberMessageStore startListening ==========")
        print("organizationId:", safeOrganizationId)
        print("uid:", uid)
        print("mode:", mode)
        print("path: organizations/\(safeOrganizationId)/messages")

        listener?.remove()

        guard !safeOrganizationId.isEmpty else {
            items = []
            unreadCount = 0
            isLoading = false
            errorMessage = "organizationId がありません"
            updateBadge()
            return
        }

        isLoading = true
        errorMessage = nil

        listener = db.collection("organizations")
            .document(safeOrganizationId)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in

                if let error {
                    Task { @MainActor in
                        self?.isLoading = false
                        self?.errorMessage = error.localizedDescription
                        self?.items = []
                        self?.unreadCount = 0
                        self?.updateBadge()
                        print("❌ MemberMessageStore error:", error.localizedDescription)
                    }
                    return
                }

                let documents = snapshot?.documents ?? []

                let loadedItems = documents.compactMap { doc in
                    Self.makeItem(
                        from: doc,
                        uid: uid,
                        mode: mode,
                        baseline: messageReadBaselineAt
                    )
                }

                Task { @MainActor in
                    self?.isLoading = false
                    self?.items = loadedItems
                    self?.unreadCount = loadedItems.filter { !$0.isRead }.count
                    self?.updateBadge()

                    print("✅ MemberMessageStore 件数:", loadedItems.count)
                    print("🔴 MemberMessageStore 未読:", self?.unreadCount ?? 0)
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func markAsRead(messageId: String, organizationId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let safeOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !safeOrganizationId.isEmpty else { return }

        do {
            try await db.collection("organizations")
                .document(safeOrganizationId)
                .collection("messages")
                .document(messageId)
                .updateData([
                    "isReadBy": FieldValue.arrayUnion([uid])
                ])
        } catch {
            print("❌ 既読更新失敗:", error.localizedDescription)
        }
    }

    private static func makeItem(
        from document: QueryDocumentSnapshot,
        uid: String,
        mode: String,
        baseline: Date?
    ) -> MemberMessageItem? {

        let data = document.data()

        let messageType = data["messageType"] as? String ?? ""
        let targetType = data["targetType"] as? String ?? ""
        let isBroadcast = data["isBroadcast"] as? Bool ?? false

        if mode == "public" {
            let isPublic =
                messageType == "publicAnnouncement" ||
                messageType == "announcement" ||
                targetType == "public"

            guard isPublic else { return nil }
        }

        if mode == "member" {
            let isPublic =
                messageType == "publicAnnouncement" ||
                messageType == "announcement" ||
                targetType == "public"

            let isMemberMessage =
                messageType == "memberMessage" ||
                targetType == "members" ||
                isBroadcast

            guard isPublic || isMemberMessage else { return nil }
        }

        let title = data["title"] as? String ?? ""
        let body = data["body"] as? String ?? ""

        let createdAt: Date =
            (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

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

    private func updateBadge() {
        UIApplication.shared.applicationIconBadgeNumber = unreadCount
        print("🔴 バッジ更新:", unreadCount)
    }
}
