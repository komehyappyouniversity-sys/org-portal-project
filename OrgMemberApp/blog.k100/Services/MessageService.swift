import Foundation
import FirebaseFirestore
import FirebaseAuth

protocol MessageServiceProtocol {
    func fetchMessages(organizationId: String) async throws -> [MemberMessageItem]

    func listenMessages(
        organizationId: String,
        onChange: @escaping (Result<[MemberMessageItem], Error>) -> Void
    ) -> ListenerRegistration
}

final class MessageService: MessageServiceProtocol {
    private let db = Firestore.firestore()

    func fetchMessages(organizationId: String) async throws -> [MemberMessageItem] {
        let trimmedOrganizationId = organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOrganizationId.isEmpty else {
            return []
        }

        let currentUid = Auth.auth().currentUser?.uid ?? ""

        let snapshot = try await db.collection("organizations")
            .document(trimmedOrganizationId)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.map { document in
            let data = document.data()
            let readBy = data["isReadBy"] as? [String] ?? []

            return MemberMessageItem(
                id: document.documentID,
                title: data["title"] as? String ?? "",
                body: data["body"] as? String ?? "",
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                isRead: readBy.contains(currentUid)
            )
        }
    }

    func listenMessages(
        organizationId: String,
        onChange: @escaping (Result<[MemberMessageItem], Error>) -> Void
    ) -> ListenerRegistration {
        let trimmedOrganizationId = organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let currentUid = Auth.auth().currentUser?.uid ?? ""

        return db.collection("organizations")
            .document(trimmedOrganizationId)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let documents = snapshot?.documents ?? []

                let items = documents.map { document in
                    let data = document.data()
                    let readBy = data["isReadBy"] as? [String] ?? []

                    return MemberMessageItem(
                        id: document.documentID,
                        title: data["title"] as? String ?? "",
                        body: data["body"] as? String ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        isRead: readBy.contains(currentUid)
                    )
                }

                onChange(.success(items))
            }
    }
}
