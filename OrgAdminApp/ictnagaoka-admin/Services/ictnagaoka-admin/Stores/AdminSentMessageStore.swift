import Foundation
import Combine
import FirebaseFirestore

struct AdminSentMessageItem: Identifiable {
    let id: String
    let title: String
    let body: String
    let createdAt: Date?
    let readCount: Int
    let targetCount: Int

    var unreadCount: Int {
        max(targetCount - readCount, 0)
    }

    init(id: String, data: [String: Any], approvedMemberCount: Int) {
        self.id = id
        self.title = data["title"] as? String ?? ""
        self.body = data["body"] as? String ?? ""

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else if let timestamp = data["publishedAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = nil
        }

        let isReadBy = data["isReadBy"] as? [String] ?? []
        self.readCount = isReadBy.count

        // 重要：
        // 保存済みの targetMemberUids が4件あっても使わず、
        // 現在の承認済み members 数を正とする
        self.targetCount = approvedMemberCount
    }
}

@MainActor
final class AdminSentMessageStore: ObservableObject {
    @Published var items: [AdminSentMessageItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var messageListener: ListenerRegistration?
    private var memberListener: ListenerRegistration?

    private var latestMessageDocs: [QueryDocumentSnapshot] = []
    private var approvedMemberCount: Int = 0

    deinit {
        messageListener?.remove()
        memberListener?.remove()
    }

    func startListening(organizationId: String) {
        isLoading = true
        errorMessage = nil

        messageListener?.remove()
        memberListener?.remove()

        listenApprovedMemberCount(organizationId: organizationId)
        listenMessages(organizationId: organizationId)
    }

    private func listenApprovedMemberCount(organizationId: String) {
        memberListener = db.collection("organizations")
            .document(organizationId)
            .collection("members")
            .whereField("status", in: ["approved", "active"])
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    self.approvedMemberCount = snapshot?.documents.count ?? 0
                    self.rebuildItems()
                }
            }
    }

    private func listenMessages(organizationId: String) {
        messageListener = db.collection("organizations")
            .document(organizationId)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    self.latestMessageDocs = snapshot?.documents ?? []
                    self.rebuildItems()
                }
            }
    }

    private func rebuildItems() {
        items = latestMessageDocs.map { doc in
            AdminSentMessageItem(
                id: doc.documentID,
                data: doc.data(),
                approvedMemberCount: approvedMemberCount
            )
        }
    }
}
