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
    func markAsRead(messageId: String, uid: String, organizationId: String) async throws
    func sendMessage(_ payload: SendMessageRequest) async throws
    func fetchSentMessages(organizationId: String) async throws -> [MessageItem]
}

final class MessageService: MessageServiceProtocol {
    private let db = Firestore.firestore()

    private func messagesRef(organizationId: String) -> CollectionReference {
        db.collection("organizations")
            .document(organizationId)
            .collection("messages")
    }

    func fetchMessages(for uid: String, organizationId: String) async throws -> [MessageItem] {
        let safeOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        let snapshot = try await messagesRef(organizationId: safeOrganizationId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            let isBroadcast = data["isBroadcast"] as? Bool ?? false
            let targetMemberUids = data["targetMemberUids"] as? [String] ?? []
            let toUids = data["toUids"] as? [String] ?? []

            guard isBroadcast || targetMemberUids.contains(uid) || toUids.contains(uid) else {
                return nil
            }

            return Self.makeMessageItem(from: doc)
        }
    }

    func listenMessages(
        for uid: String,
        organizationId: String,
        onChange: @escaping (Result<[MessageItem], Error>) -> Void
    ) -> ListenerRegistration {
        let safeOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        return messagesRef(organizationId: safeOrganizationId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let documents = snapshot?.documents ?? []

                let items = documents.compactMap { doc -> MessageItem? in
                    let data = doc.data()
                    let isBroadcast = data["isBroadcast"] as? Bool ?? false
                    let targetMemberUids = data["targetMemberUids"] as? [String] ?? []
                    let toUids = data["toUids"] as? [String] ?? []

                    guard isBroadcast || targetMemberUids.contains(uid) || toUids.contains(uid) else {
                        return nil
                    }

                    return Self.makeMessageItem(from: doc)
                }

                onChange(.success(items))
            }
    }

    func markAsRead(messageId: String, uid: String, organizationId: String) async throws {
        let safeOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        try await messagesRef(organizationId: safeOrganizationId)
            .document(messageId)
            .updateData([
                "isReadBy": FieldValue.arrayUnion([uid]),
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    func sendMessage(_ payload: SendMessageRequest) async throws {
        let safeOrganizationId = payload.organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Timestamp(date: Date())

        let isBroadcast =
            payload.deliveryType == "broadcast" ||
            payload.deliveryType == "all" ||
            payload.targetMemberUids.isEmpty

        let data: [String: Any] = [
            "organizationId": safeOrganizationId,
            "messageType": "memberMessage",
            "title": payload.title,
            "body": payload.body,
            "deliveryType": payload.deliveryType,
            "isBroadcast": isBroadcast,
            "categoryTargets": payload.categoryTargets,
            "targetMemberUids": payload.targetMemberUids,
            "targetCount": payload.targetMemberUids.count,
            "isReadBy": [],
            "createdBy": payload.createdBy,
            "createdAt": now,
            "updatedAt": now
        ]

        try await messagesRef(organizationId: safeOrganizationId)
            .addDocument(data: data)
    }

    func fetchSentMessages(organizationId: String) async throws -> [MessageItem] {
        let safeOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        let snapshot = try await messagesRef(organizationId: safeOrganizationId)
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
