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
            requests = []
            isLoading = false
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

                if let error {
                    let message = error.localizedDescription

                    Task { @MainActor in
                        self?.isLoading = false
                        self?.errorMessage = message
                    }
                    return
                }

                let rawItems: [AdminRequestItem] = snapshot?.documents.compactMap { doc in
                    AdminRequestItem(
                        document: doc,
                        organizationId: safeOrganizationId
                    )
                } ?? []

                var seen = Set<String>()

                let filteredItems = rawItems.filter { item in
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

                Task { @MainActor in
                    self?.isLoading = false
                    self?.errorMessage = nil
                    self?.requests = filteredItems
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

        let reviewedByUid = Auth.auth().currentUser?.uid ?? ""
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
            "reviewedByUid": reviewedByUid,
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

        let reviewedByUid = Auth.auth().currentUser?.uid ?? ""

        try await db.collection("organizations")
            .document(organizationId)
            .collection("memberRegistrations")
            .document(request.id)
            .updateData([
                "status": "rejected",
                "rejectReason": reason,
                "reviewedByUid": reviewedByUid,
                "reviewedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }
}
