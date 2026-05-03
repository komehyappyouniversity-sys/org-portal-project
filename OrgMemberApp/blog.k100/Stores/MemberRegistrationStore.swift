//
//  MemberRegistrationStore.swift
//  blog.k100
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

struct MemberRegistrationForm: Equatable {
    var name: String = ""
    var kana: String = ""
    var birthDate: Date = Date()
    var email: String = ""
    var phone: String = ""

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedKana: String { kana.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedPhone: String { phone.trimmingCharacters(in: .whitespacesAndNewlines) }
}

@MainActor
final class MemberRegistrationStore: ObservableObject {
    @Published var form = MemberRegistrationForm()
    @Published var isSubmitting = false
    @Published var errorMessage = ""
    @Published var successMessage = ""

    private let db = Firestore.firestore()

    func startListeningMyLatestRegistration(organizationId: String) {
        // members/{uid} に統一するため、ここでは何もしません
    }

    func stopListening() {}

    func submit(organizationId: String) async -> Bool {
        errorMessage = ""
        successMessage = ""

        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            errorMessage = "organizationId が取得できません。"
            return false
        }

        guard !form.trimmedName.isEmpty else {
            errorMessage = "氏名を入力してください。"
            return false
        }

        guard !form.trimmedKana.isEmpty else {
            errorMessage = "フリガナを入力してください。"
            return false
        }

        guard !form.trimmedPhone.isEmpty else {
            errorMessage = "電話番号を入力してください。"
            return false
        }

        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            errorMessage = "ログインUIDが取得できません。"
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let ref = db.collection("organizations")
                .document(orgId)
                .collection("members")
                .document(uid)

            let data: [String: Any] = [
                "uid": uid,
                "organizationId": orgId,
                "name": form.trimmedName,
                "kana": form.trimmedKana,
                "birthDate": Timestamp(date: form.birthDate),
                "email": form.trimmedEmail,
                "phone": form.trimmedPhone,
                "status": "pending",
                "updatedAt": FieldValue.serverTimestamp()
            ]

            print("=== 会員登録 保存開始 ===")
            print("path: organizations/\(orgId)/members/\(uid)")
            print("status: pending")

            try await ref.setData(data, merge: true)

            successMessage = "会員登録申請を受け付けました"
            return true

        } catch {
            print("❌ MemberRegistration save error:", error.localizedDescription)
            errorMessage = "申請保存エラー: \(error.localizedDescription)"
            return false
        }
    }

    func clearMessages() {
        errorMessage = ""
        successMessage = ""
    }

    func clearForm() {
        form = MemberRegistrationForm()
        clearMessages()
    }
}
