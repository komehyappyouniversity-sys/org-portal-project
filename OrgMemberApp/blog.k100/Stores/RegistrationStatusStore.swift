//
//  RegistrationStatusStore.swift
//  blog.k100
//
//  Created by 根津浩 on 2026/04/13.
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

    private var registrationListener: ListenerRegistration?
    private var memberListener: ListenerRegistration?

    deinit {
        registrationListener?.remove()
        memberListener?.remove()
    }

    func start() {
        registrationListener?.remove()
        memberListener?.remove()

        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            currentUID = ""
            state = .notSignedIn
            return
        }

        currentUID = uid
        watchRegistration(uid: uid)
        watchMember(uid: uid)
    }

    func refresh() {
        start()
    }

    private func watchRegistration(uid: String) {
        let db = Firestore.firestore()

        registrationListener?.remove()
        registrationListener = db
            .collection("organizations")
            .document("nagaoka")
            .collection("memberRegistrations")
            .document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.state = .error("申請状態取得エラー: \(error.localizedDescription)")
                    return
                }

                guard let snapshot else {
                    self.state = .notRegistered
                    return
                }

                guard snapshot.exists else {
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

    private func watchMember(uid: String) {
        let db = Firestore.firestore()

        memberListener?.remove()
        memberListener = db
            .collection("organizations")
            .document("nagaoka")
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
