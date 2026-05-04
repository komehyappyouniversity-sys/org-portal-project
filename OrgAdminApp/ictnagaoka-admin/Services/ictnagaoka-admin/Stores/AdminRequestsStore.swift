import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class AdminRequestsStore: ObservableObject {
    @Published var requests: [AdminRequestItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func startListening(organizationId: String) {
        let safeOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !safeOrganizationId.isEmpty else {
            errorMessage = "organizationId が空です。"
            return
        }

        stopListening()
        isLoading = true
        errorMessage = nil

        listener = db.collection("organizations")
            .document(safeOrganizationId)
            .collection("memberRegistrations")
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    let rawItems: [AdminRequestItem] = snapshot?.documents.compactMap { doc in
                        AdminRequestItem(
                            document: doc,
                            organizationId: safeOrganizationId
                        )
                    } ?? []

                    var seen = Set<String>()

                    self.requests = rawItems.filter { item in
                        let key: String

                        if !item.uid.isEmpty {
                            key = "uid:\(item.uid)"
                        } else {
                            key = "email:\(item.email.lowercased())"
                        }

                        if seen.contains(key) {
                            return false
                        }

                        seen.insert(key)
                        return true
                    }
                }
            }
    }

    func approve(request: AdminRequestItem) async throws {
        let organizationId = request.organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !organizationId.isEmpty else {
            throw NSError(
                domain: "AdminRequestsStore",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "organizationId が空です"]
            )
        }

        guard !request.uid.isEmpty else {
            throw NSError(
                domain: "AdminRequestsStore",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "UIDが空です"]
            )
        }

        let batch = db.batch()

        let registrationRef = db.collection("organizations")
            .document(organizationId)
            .collection("memberRegistrations")
            .document(request.id)

        let memberRef = db.collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(request.uid)

        batch.setData([
            "organizationId": organizationId,
            "uid": request.uid,
            "name": request.name,
            "kana": request.furigana,
            "memberCode": request.memberId,
            "phone": request.phone,
            "email": request.email,
            "status": "approved",
            "createdFromRegistrationId": request.id,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: memberRef, merge: true)

        batch.updateData([
            "status": "approved",
            "reviewedByUid": Auth.auth().currentUser?.uid ?? "",
            "reviewedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: registrationRef)

        try await batch.commit()
    }

    func reject(request: AdminRequestItem, reason: String) async throws {
        let organizationId = request.organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !organizationId.isEmpty else {
            throw NSError(
                domain: "AdminRequestsStore",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "organizationId が空です"]
            )
        }

        try await db.collection("organizations")
            .document(organizationId)
            .collection("memberRegistrations")
            .document(request.id)
            .updateData([
                "status": "rejected",
                "rejectReason": reason,
                "reviewedByUid": Auth.auth().currentUser?.uid ?? "",
                "reviewedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }
}
