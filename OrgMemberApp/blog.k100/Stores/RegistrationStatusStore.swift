//
//  RegistrationStatusStore.swift
//  blog.k100
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class RegistrationStatusStore: ObservableObject {

    enum RegistrationState: Equatable {
        case checking
        case notSignedIn
        case notRegistered
        case pending
        case approved
        case rejected
        case error(String)
    }

    @Published var state: RegistrationState = .checking
    @Published var currentUID: String = ""

    private var currentOrganizationId: String = ""

    private var registrationListener: ListenerRegistration?
    private var memberListener: ListenerRegistration?

    deinit {
        registrationListener?.remove()
        memberListener?.remove()
    }

    func setOrganizationId(_ organizationId: String) {
        let trimmed = organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return
        }

        if currentOrganizationId == trimmed {
            return
        }

        currentOrganizationId = trimmed
        start()
    }

    func start() {
        registrationListener?.remove()
        memberListener?.remove()

        guard !currentOrganizationId.isEmpty else {
            currentUID = ""
            state = .error("コミュニティ情報が取得できません。")
            return
        }

        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            currentUID = ""
            state = .notSignedIn
            return
        }

        currentUID = uid
        state = .checking

        watchRegistration(uid: uid, organizationId: currentOrganizationId)
        watchMember(uid: uid, organizationId: currentOrganizationId)
    }

    func refresh() {
        start()
    }

    private func watchRegistration(
        uid: String,
        organizationId: String
    ) {
        let db = Firestore.firestore()

        registrationListener?.remove()

        registrationListener = db
            .collection("organizations")
            .document(organizationId)
            .collection("memberRegistrations")
            .document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.state = .error("申請状態取得エラー: \(error.localizedDescription)")
                    return
                }

                guard let snapshot, snapshot.exists else {
                    self.state = .notRegistered
                    return
                }

                let data = snapshot.data() ?? [:]
                let status = data["status"] as? String ?? "pending"

                switch status {
                case "approved":
                    self.state = .approved
                case "rejected":
                    self.state = .rejected
                case "pending":
                    self.state = .pending
                default:
                    self.state = .pending
                }
            }
    }

    private func watchMember(
        uid: String,
        organizationId: String
    ) {
        let db = Firestore.firestore()

        memberListener?.remove()

        memberListener = db
            .collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.state = .error("会員情報取得エラー: \(error.localizedDescription)")
                    return
                }

                guard let snapshot, snapshot.exists else {
                    return
                }

                let data = snapshot.data() ?? [:]
                let status = data["status"] as? String ?? ""

                if status == "approved" {
                    self.state = .approved
                }
            }
    }
}
