//
//  AdminRequestsStore.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/16.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class AdminRequestsStore: ObservableObject {
    @Published var requests: [AdminRequestItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    // MARK: - Listening

    func startListening(organizationId: String) {
        let safeOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !safeOrganizationId.isEmpty else {
            requests = []
            errorMessage = "organizationId が空です。"
            isLoading = false
            return
        }

        listener?.remove()
        listener = nil

        isLoading = true
        errorMessage = ""

        listener = Firestore.firestore()
            .collection("organizations")
            .document(safeOrganizationId)
            .collection("memberRegistrations")
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                Task { @MainActor in
                    if let error {
                        self.requests = []
                        self.isLoading = false
                        self.errorMessage = "申請一覧の取得に失敗しました: \(error.localizedDescription)"
                        return
                    }

                    guard let snapshot else {
                        self.requests = []
                        self.isLoading = false
                        self.errorMessage = ""
                        return
                    }

                    self.requests = snapshot.documents.compactMap {
                        AdminRequestItem(document: $0, organizationId: safeOrganizationId)
                    }
                    self.isLoading = false
                    self.errorMessage = ""
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Approve

    func approve(request: AdminRequestItem) async throws {
        let safeOrganizationId = request.organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !safeOrganizationId.isEmpty else {
            throw NSError(
                domain: "AdminRequestsStore",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "organizationId が空です。"]
            )
        }

        let db = Firestore.firestore()
        let now = Timestamp(date: Date())

        let registrationRef = db.collection("organizations")
            .document(safeOrganizationId)
            .collection("memberRegistrations")
            .document(request.id)

        let memberRef = db.collection("organizations")
            .document(safeOrganizationId)
            .collection("members")
            .document(request.uid.isEmpty ? request.id : request.uid)

        var memberData: [String: Any] = [
            "uid": request.uid,
            "memberId": request.memberId,
            "name": request.name,
            "furigana": request.furigana,
            "phone": request.phone,
            "email": request.email,
            "address": request.address,
            "note": request.note,
            "status": "approved",
            "updatedAt": now,
            "approvedAt": now
        ]

        if let existingCreatedAt = request.createdAt {
            memberData["createdAt"] = Timestamp(date: existingCreatedAt)
        } else {
            memberData["createdAt"] = now
        }

        try await memberRef.setData(memberData, merge: true)

        try await registrationRef.updateData([
            "status": "approved",
            "updatedAt": now,
            "approvedAt": now
        ])
    }

    // MARK: - Reject

    func reject(
        request: AdminRequestItem,
        reason: String = ""
    ) async throws {
        let safeOrganizationId = request.organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !safeOrganizationId.isEmpty else {
            throw NSError(
                domain: "AdminRequestsStore",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "organizationId が空です。"]
            )
        }

        let now = Timestamp(date: Date())

        var data: [String: Any] = [
            "status": "rejected",
            "updatedAt": now
        ]

        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedReason.isEmpty {
            data["rejectReason"] = trimmedReason
        }

        try await Firestore.firestore()
            .collection("organizations")
            .document(safeOrganizationId)
            .collection("memberRegistrations")
            .document(request.id)
            .updateData(data)
    }
}
