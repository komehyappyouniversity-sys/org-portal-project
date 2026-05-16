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

    init(id: String, data: [String: Any], targetMemberUids: [String]) {
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

        let targetSet = Set(targetMemberUids)
        let isReadBy = data["isReadBy"] as? [String] ?? []
        let readSet = Set(isReadBy)

        self.targetCount = targetSet.count
        self.readCount = targetSet.intersection(readSet).count
    }
}

private struct AdminSentMessageMember {
    let uid: String
    let status: String
    let categories: [String]

    var isApproved: Bool {
        status == "approved" || status == "active"
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
    private var latestMembers: [AdminSentMessageMember] = []

    deinit {
        messageListener?.remove()
        memberListener?.remove()
    }

    func startListening(organizationId: String) {
        let trimmedOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOrganizationId.isEmpty else {
            items = []
            isLoading = false
            errorMessage = "organizationId が空です。"
            return
        }

        isLoading = true
        errorMessage = nil

        messageListener?.remove()
        memberListener?.remove()

        latestMessageDocs = []
        latestMembers = []

        listenMembers(organizationId: trimmedOrganizationId)
        listenMessages(organizationId: trimmedOrganizationId)
    }

    func stopListening() {
        messageListener?.remove()
        memberListener?.remove()

        messageListener = nil
        memberListener = nil

        latestMessageDocs = []
        latestMembers = []
        items = []
        isLoading = false
    }

    private func listenMembers(organizationId: String) {
        memberListener = db.collection("organizations")
            .document(organizationId)
            .collection("members")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = "会員情報の取得に失敗しました: \(error.localizedDescription)"
                        self.rebuildItems()
                        return
                    }

                    self.latestMembers = snapshot?.documents.compactMap { doc in
                        let data = doc.data()

                        let status = data["status"] as? String ?? ""

                        let categories = data["categories"] as? [String] ?? []
                        let legacyCategory = data["category"] as? String ?? ""

                        let mergedCategories = categories + (
                            legacyCategory.isEmpty ? [] : [legacyCategory]
                        )

                        return AdminSentMessageMember(
                            uid: doc.documentID,
                            status: status,
                            categories: mergedCategories
                        )
                    } ?? []

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
                        self.errorMessage = "送信済みメッセージの取得に失敗しました: \(error.localizedDescription)"
                        self.rebuildItems()
                        return
                    }

                    self.latestMessageDocs = snapshot?.documents ?? []
                    self.rebuildItems()
                }
            }
    }

    private func rebuildItems() {
        let approvedMembers = latestMembers.filter { $0.isApproved }

        items = latestMessageDocs.map { doc in
            let data = doc.data()
            let targetUids = resolveTargetUids(
                data: data,
                approvedMembers: approvedMembers
            )

            return AdminSentMessageItem(
                id: doc.documentID,
                data: data,
                targetMemberUids: targetUids
            )
        }
    }

    private func resolveTargetUids(
        data: [String: Any],
        approvedMembers: [AdminSentMessageMember]
    ) -> [String] {
        let isBroadcast = data["isBroadcast"] as? Bool ?? false
        let categoryTargets = data["categoryTargets"] as? [String] ?? []

        let targetMemberUids = data["targetMemberUids"] as? [String] ?? []
        let toUids = data["toUids"] as? [String] ?? []

        if isBroadcast {
            return approvedMembers.map { $0.uid }
        }

        if !categoryTargets.isEmpty {
            let categoryTargetSet = Set(categoryTargets)

            return approvedMembers
                .filter { member in
                    member.categories.contains { category in
                        categoryTargetSet.contains(category)
                    }
                }
                .map { $0.uid }
        }

        let directTargetSet = Set(targetMemberUids + toUids)

        return approvedMembers
            .filter { directTargetSet.contains($0.uid) }
            .map { $0.uid }
    }
}
