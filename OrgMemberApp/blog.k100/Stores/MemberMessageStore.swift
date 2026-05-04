import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class MemberMessageStore: ObservableObject {
    @Published var items: [MemberMessageItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var baselineListener: ListenerRegistration?

    private var locallyReadMessageIds: Set<String> = []
    private var messageReadBaselineAt: Date?

    var unreadCount: Int {
        items.filter { !$0.isRead }.count
    }

    deinit {
        listener?.remove()
        baselineListener?.remove()
    }

    func startListening(organizationId: String, visibility: String) {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let mode = visibility.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let uid = Auth.auth().currentUser?.uid

        guard !orgId.isEmpty else {
            items = []
            errorMessage = "organizationId が空です"
            return
        }

        listener?.remove()
        baselineListener?.remove()

        isLoading = true
        errorMessage = ""

        if let uid {
            startBaselineListening(organizationId: orgId, uid: uid)
        }

        print("========== MemberMessageStore startListening ==========")
        print("organizationId:", orgId)
        print("mode:", mode)
        print("uid:", uid ?? "nil")
        print("path: organizations/\(orgId)/messages")

        listener = db.collection("organizations")
            .document(orgId)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    self.items = []
                    print("❌ messages listen error:", error.localizedDescription)
                    return
                }

                let docs = snapshot?.documents ?? []

                self.items = docs.compactMap { doc in
                    let data = doc.data()

                    let title = data["title"] as? String ?? ""
                    let body = data["body"] as? String ?? ""

                    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return nil
                    }

                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                    let messageVisibility = (data["visibility"] as? String ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()

                    let targetType = (data["targetType"] as? String ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()

                    let deliveryType = (data["deliveryType"] as? String ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    let isBroadcast = data["isBroadcast"] as? Bool ?? false
                    let isPublished = data["isPublished"] as? Bool ?? true

                    let toUid = (data["toUid"] as? String ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    let toUids = data["toUids"] as? [String] ?? []
                    let readBy = data["isReadBy"] as? [String] ?? []

                    let isPublicMessage =
                        messageVisibility == "public" ||
                        targetType == "public" ||
                        deliveryType == "公開お知らせ"

                    let isMemberMessage =
                        messageVisibility == "member" ||
                        targetType == "member" ||
                        targetType == "members" ||
                        targetType == "allmembers" ||
                        targetType == "all_members" ||
                        deliveryType == "承認済み会員全員" ||
                        deliveryType == "カテゴリ対象" ||
                        deliveryType == "個別送信"

                    let shouldShow: Bool

                    if mode == "public" {
                        shouldShow = isPublished && isPublicMessage
                    } else {
                        if isPublicMessage {
                            shouldShow = isPublished
                        } else if let uid, toUid == uid {
                            shouldShow = true
                        } else if let uid, toUids.contains(uid) {
                            shouldShow = true
                        } else if isBroadcast && isMemberMessage {
                            shouldShow = true
                        } else if isMemberMessage {
                            shouldShow = true
                        } else {
                            shouldShow = false
                        }
                    }

                    guard shouldShow else { return nil }

                    let isOlderThanBaseline: Bool
                    if let baseline = self.messageReadBaselineAt {
                        isOlderThanBaseline = createdAt < baseline
                    } else {
                        isOlderThanBaseline = false
                    }

                    let isRead: Bool
                    if let uid {
                        isRead =
                            isOlderThanBaseline ||
                            readBy.contains(uid) ||
                            self.locallyReadMessageIds.contains(doc.documentID)
                    } else {
                        isRead = true
                    }

                    return MemberMessageItem(
                        id: doc.documentID,
                        title: title,
                        body: body,
                        createdAt: createdAt,
                        isRead: isRead
                    )
                }

                self.objectWillChange.send()

                print("✅ messages loaded:", self.items.count)
                print("✅ unreadCount:", self.unreadCount)
                for item in self.items {
                    print("message:", item.title, "isRead:", item.isRead)
                }
            }
    }

    private func startBaselineListening(organizationId: String, uid: String) {
        let ref = db.collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)

        baselineListener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                print("❌ baseline listen error:", error.localizedDescription)
                return
            }

            let data = snapshot?.data() ?? [:]

            if let baseline = (data["messageReadBaselineAt"] as? Timestamp)?.dateValue() {
                self.messageReadBaselineAt = baseline
                print("✅ messageReadBaselineAt:", baseline)
                self.recalculateUnreadByBaseline()
            } else {
                ref.setData([
                    "messageReadBaselineAt": FieldValue.serverTimestamp()
                ], merge: true) { error in
                    if let error {
                        print("❌ baseline 保存失敗:", error.localizedDescription)
                    } else {
                        print("✅ baseline 初回保存")
                    }
                }
            }
        }
    }

    private func recalculateUnreadByBaseline() {
        guard let baseline = messageReadBaselineAt else { return }

        var didChange = false

        for index in items.indices {
            if items[index].createdAt < baseline && items[index].isRead == false {
                items[index].isRead = true
                didChange = true
            }
        }

        if didChange {
            objectWillChange.send()
            print("✅ baseline反映後 unreadCount:", unreadCount)
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil

        baselineListener?.remove()
        baselineListener = nil
    }

    func markAsRead(item: MemberMessageItem, organizationId: String) {
        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        locallyReadMessageIds.insert(item.id)

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isRead = true
            objectWillChange.send()
            print("✅ local markAsRead:", item.id, "unreadCount:", unreadCount)
        }

        db.collection("organizations")
            .document(orgId)
            .collection("messages")
            .document(item.id)
            .updateData([
                "isReadBy": FieldValue.arrayUnion([uid])
            ]) { error in
                if let error {
                    print("❌ markAsRead error:", error.localizedDescription)
                } else {
                    print("✅ markAsRead success:", item.id)
                }
            }
    }
}
