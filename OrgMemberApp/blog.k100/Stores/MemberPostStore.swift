import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

struct MemberPostAttachment: Identifiable, Equatable {
    let id: String
    let type: String
    let fileName: String
    let url: String

    init(id: String = UUID().uuidString, type: String, fileName: String, url: String) {
        self.id = id
        self.type = type
        self.fileName = fileName
        self.url = url
    }

    init(data: [String: Any]) {
        self.id = data["id"] as? String ?? UUID().uuidString
        self.type = data["type"] as? String ?? ""
        self.fileName = data["fileName"] as? String ?? ""
        self.url = data["url"] as? String ?? ""
    }

    var dictionary: [String: Any] {
        [
            "id": id,
            "type": type,
            "fileName": fileName,
            "url": url
        ]
    }

    var isImage: Bool {
        type == "image"
    }

    var isPDF: Bool {
        type == "pdf"
    }
}

struct MemberPostItem: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let createdAt: Date
    let replyBody: String?
    let replyCount: Int
    var hasUnreadReply: Bool
    let attachments: [MemberPostAttachment]
}

struct MemberPostReplyItem: Identifiable, Equatable {
    let id: String
    let body: String
    let createdBy: String
    let createdByName: String
    let createdAt: Date
}

@MainActor
final class MemberPostStore: ObservableObject {
    @Published var posts: [MemberPostItem] = []
    @Published var replies: [MemberPostReplyItem] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingReplies: Bool = false
    @Published var errorMessage: String = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var repliesListener: ListenerRegistration?

    deinit {
        listener?.remove()
        repliesListener?.remove()
    }

    func startListening(organizationId: String, memberUid: String) {
        let trimmedOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMemberUid = memberUid.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOrganizationId.isEmpty else {
            posts = []
            errorMessage = "organizationId が空です。"
            return
        }

        guard !trimmedMemberUid.isEmpty else {
            posts = []
            errorMessage = "memberUid が取得できません。"
            return
        }

        listener?.remove()
        isLoading = true
        errorMessage = ""

        listener = db.collection("organizations")
            .document(trimmedOrganizationId)
            .collection("memberPosts")
            .whereField("memberUid", isEqualTo: trimmedMemberUid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    self.posts = []
                    print("❌ MemberPostStore listen error:", error.localizedDescription)
                    return
                }

                let documents = snapshot?.documents ?? []

                self.posts = documents.map { document in
                    let data = document.data()

                    let attachmentData = data["attachments"] as? [[String: Any]] ?? []
                    let attachments = attachmentData.map {
                        MemberPostAttachment(data: $0)
                    }

                    return MemberPostItem(
                        id: document.documentID,
                        title: data["title"] as? String ?? "",
                        body: data["body"] as? String ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        replyBody: data["replyBody"] as? String,
                        replyCount: data["replyCount"] as? Int ?? 0,
                        hasUnreadReply: data["memberHasReadReply"] as? Bool == false,
                        attachments: attachments
                    )
                }
            }
    }

    func startListeningReplies(postId: String, organizationId: String) {
        let trimmedOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPostId = postId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOrganizationId.isEmpty else { return }
        guard !trimmedPostId.isEmpty else { return }

        repliesListener?.remove()
        replies = []
        isLoadingReplies = true

        repliesListener = db.collection("organizations")
            .document(trimmedOrganizationId)
            .collection("memberPosts")
            .document(trimmedPostId)
            .collection("replies")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                self.isLoadingReplies = false

                if let error {
                    print("❌ replies listen error:", error.localizedDescription)
                    self.replies = []
                    return
                }

                let documents = snapshot?.documents ?? []

                self.replies = documents.map { document in
                    let data = document.data()

                    return MemberPostReplyItem(
                        id: document.documentID,
                        body: data["body"] as? String ?? "",
                        createdBy: data["createdBy"] as? String ?? "",
                        createdByName: data["createdByName"] as? String ?? "管理者",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func stopListeningReplies() {
        repliesListener?.remove()
        repliesListener = nil
        replies = []
    }

    func markReplyAsRead(postId: String, organizationId: String) {
        let trimmedOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPostId = postId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOrganizationId.isEmpty else { return }
        guard !trimmedPostId.isEmpty else { return }

        if let index = posts.firstIndex(where: { $0.id == trimmedPostId }) {
            posts[index].hasUnreadReply = false
        }

        db.collection("organizations")
            .document(trimmedOrganizationId)
            .collection("memberPosts")
            .document(trimmedPostId)
            .updateData([
                "memberHasReadReply": true
            ]) { error in
                if let error {
                    print("❌ markReplyAsRead error:", error.localizedDescription)
                } else {
                    print("✅ 返信既読更新:", trimmedPostId)
                }
            }
    }
}
