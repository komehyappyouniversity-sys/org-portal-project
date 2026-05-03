import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

struct MemberPostItem: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let createdAt: Date
    let replyBody: String?
    var hasUnreadReply: Bool
}

@MainActor
final class MemberPostStore: ObservableObject {
    @Published var posts: [MemberPostItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
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

                    return MemberPostItem(
                        id: document.documentID,
                        title: data["title"] as? String ?? "",
                        body: data["body"] as? String ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        replyBody: data["replyBody"] as? String,
                        hasUnreadReply: data["memberHasReadReply"] as? Bool == false
                    )
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
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
                }
            }
    }
}
