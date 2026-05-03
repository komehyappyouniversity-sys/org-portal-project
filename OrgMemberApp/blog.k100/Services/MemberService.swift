//
//  MemberService.swift
//  blog.k100
//
//  Created by 根津浩 on 2026/04/15.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct MemberRegistrationPayload {
    let uid: String
    let organizationId: String
    let name: String
    let kana: String
    let phone: String
    let email: String
    let createdAt: Date
}

struct MemberProfileUpdatePayload {
    let name: String
    let kana: String
    let phone: String
    let email: String
    let address: String
    let notes: String
    let categories: [String]
}

protocol MemberServiceProtocol {
    func ensureSignedIn() async throws -> String
    func fetchMember(uid: String, organizationId: String) async throws -> MemberProfile?
    func listenMember(
        uid: String,
        organizationId: String,
        onChange: @escaping (Result<MemberProfile?, Error>) -> Void
    ) -> ListenerRegistration
    func submitRegistration(_ payload: MemberRegistrationPayload) async throws
    func updateMemberProfile(
        uid: String,
        organizationId: String,
        payload: MemberProfileUpdatePayload
    ) async throws
    func updateFcmToken(uid: String, organizationId: String, token: String) async throws
}

final class MemberService: MemberServiceProtocol {
    private let db = Firestore.firestore()

    func ensureSignedIn() async throws -> String {
        if let currentUser = Auth.auth().currentUser {
            return currentUser.uid
        }

        throw NSError(
            domain: "MemberService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "ログインしていません。"]
        )
    }

    func fetchMember(uid: String, organizationId: String) async throws -> MemberProfile? {
        let trimmedUid = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUid.isEmpty, !trimmedOrganizationId.isEmpty else {
            return nil
        }

        let snapshot = try await db.collection("organizations")
            .document(trimmedOrganizationId)
            .collection("members")
            .document(trimmedUid)
            .getDocument()

        guard snapshot.exists else {
            return nil
        }

        return makeMemberProfile(from: snapshot)
    }

    func listenMember(
        uid: String,
        organizationId: String,
        onChange: @escaping (Result<MemberProfile?, Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                guard let snapshot, snapshot.exists else {
                    onChange(.success(nil))
                    return
                }

                onChange(.success(self.makeMemberProfile(from: snapshot)))
            }
    }

    func submitRegistration(_ payload: MemberRegistrationPayload) async throws {
        let now = Timestamp(date: payload.createdAt)

        let registrationData: [String: Any] = [
            "uid": payload.uid,
            "organizationId": payload.organizationId,
            "name": payload.name,
            "kana": payload.kana,
            "phone": payload.phone,
            "email": payload.email,
            "status": "pending",
            "appliedAt": now,
            "createdAt": now,
            "updatedAt": now
        ]

        try await db.collection("organizations")
            .document(payload.organizationId)
            .collection("memberRegistrations")
            .document(payload.uid)
            .setData(registrationData)

        let memberData: [String: Any] = [
            "uid": payload.uid,
            "organizationId": payload.organizationId,
            "name": payload.name,
            "kana": payload.kana,
            "phone": payload.phone,
            "email": payload.email,
            "status": "pending",
            "categories": [],
            "createdAt": now,
            "updatedAt": now
        ]

        try await db.collection("organizations")
            .document(payload.organizationId)
            .collection("members")
            .document(payload.uid)
            .setData(memberData, merge: true)
    }

    func updateMemberProfile(
        uid: String,
        organizationId: String,
        payload: MemberProfileUpdatePayload
    ) async throws {
        let normalizedCategories = payload.categories
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let data: [String: Any] = [
            "name": payload.name,
            "kana": payload.kana,
            "phone": payload.phone,
            "email": payload.email,
            "address": payload.address,
            "notes": payload.notes,
            "categories": normalizedCategories,
            "updatedAt": Timestamp(date: Date())
        ]

        try await db.collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)
            .updateData(data)
    }

    func updateFcmToken(uid: String, organizationId: String, token: String) async throws {
        try await db.collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)
            .updateData([
                "fcmToken": token,
                "updatedAt": Timestamp(date: Date())
            ])
    }

    private func makeMemberProfile(from snapshot: DocumentSnapshot) -> MemberProfile {
        let data = snapshot.data() ?? [:]

        let uid = (data["uid"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? snapshot.documentID

        let name = (data["name"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""

        let status = (data["status"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""

        let categoriesArray = data["categories"] as? [String] ?? []
        let legacyCategory = (data["category"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""

        let mergedCategories = Array(
            Set(
                categoriesArray
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                +
                (legacyCategory.isEmpty ? [] : [legacyCategory])
            )
        ).sorted()

        let baselineAt = (data["messageReadBaselineAt"] as? Timestamp)?.dateValue()

        return MemberProfile(
            id: snapshot.documentID,
            uid: uid,
            name: name,
            status: status,
            messageReadBaselineAt: baselineAt
        )
    }
}
