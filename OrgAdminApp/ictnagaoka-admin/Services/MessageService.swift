import Foundation
import FirebaseFirestore

struct SendMessageRequest {
    let organizationId: String
    let title: String
    let body: String
    let deliveryType: String
    let categoryTargets: [String]
    let targetMemberUids: [String]
    let createdBy: String
}

protocol MessageServiceProtocol {
    func fetchMessages(for uid: String, organizationId: String) async throws -> [MessageItem]
    func listenMessages(
        for uid: String,
        organizationId: String,
        onChange: @escaping (Result<[MessageItem], Error>) -> Void
    ) -> ListenerRegistration
    func markAsRead(messageId: String, uid: String) async throws
    func sendMessage(_ payload: SendMessageRequest) async throws
    func fetchSentMessages(organizationId: String) async throws -> [MessageItem]
}

final class MessageService: MessageServiceProtocol {
    private let db = Firestore.firestore()

    func fetchMessages(for uid: String, organizationId: String) async throws -> [MessageItem] {
        let snapshot = try await db.collection("messages")
            .whereField("organizationId", isEqualTo: organizationId)
            .whereField("targetMemberUids", arrayContains: uid)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { Self.makeMessageItem(from: $0) }
    }

    func listenMessages(
        for uid: String,
        organizationId: String,
        onChange: @escaping (Result<[MessageItem], Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("messages")
            .whereField("organizationId", isEqualTo: organizationId)
            .whereField("targetMemberUids", arrayContains: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                guard let snapshot else {
                    onChange(.success([]))
                    return
                }

                let items = snapshot.documents.compactMap { Self.makeMessageItem(from: $0) }
                onChange(.success(items))
            }
    }

    func markAsRead(messageId: String, uid: String) async throws {
        try await db.collection("messages").document(messageId).updateData([
            "isReadBy": FieldValue.arrayUnion([uid]),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    func sendMessage(_ payload: SendMessageRequest) async throws {
        let now = Timestamp(date: Date())

        let data: [String: Any] = [
            "organizationId": payload.organizationId,
            "title": payload.title,
            "body": payload.body,
            "deliveryType": payload.deliveryType,
            "categoryTargets": payload.categoryTargets,
            "targetMemberUids": payload.targetMemberUids,
            "targetCount": payload.targetMemberUids.count,
            "isReadBy": [],
            "createdBy": payload.createdBy,
            "createdAt": now,
            "updatedAt": now
        ]

        try await db.collection("messages").addDocument(data: data)
    }

    func fetchSentMessages(organizationId: String) async throws -> [MessageItem] {
        let snapshot = try await db.collection("messages")
            .whereField("organizationId", isEqualTo: organizationId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { Self.makeMessageItem(from: $0) }
    }

    private static func makeMessageItem(from document: QueryDocumentSnapshot) -> MessageItem? {
        let data = document.data()

        return MessageItem(
            id: document.documentID,
            title: data["title"] as? String ?? "",
            body: data["body"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue(),
            isBroadcast: data["isBroadcast"] as? Bool ?? false,
            categoryTargets: data["categoryTargets"] as? [String] ?? [],
            targetMemberUids: data["targetMemberUids"] as? [String] ?? [],
            isReadBy: data["isReadBy"] as? [String] ?? []
        )
    }
}
