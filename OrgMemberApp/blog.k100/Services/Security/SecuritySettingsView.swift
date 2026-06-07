import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SecuritySettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var organizationStore: OrganizationStore

    @AppStorage("faceIDAutoLoginEnabled")
    private var faceIDAutoLoginEnabled = false

    @State private var showClearLoginAlert = false
    @State private var showDeleteAccountAlert = false

    @State private var deletePassword = ""
    @State private var isDeletePasswordVisible = false

    @State private var isLoading = false
    @State private var message = ""

    private let db = Firestore.firestore()

    var body: some View {

        List {

            Section("Face ID") {
                Toggle("Face ID自動ログイン", isOn: $faceIDAutoLoginEnabled)
            }

            Section("ログイン情報") {
                Button(role: .destructive) {
                    showClearLoginAlert = true
                } label: {
                    Text("この端末のログイン情報を削除")
                }
            }

            Section("パスワード") {
                Button {
                    resetPassword()
                } label: {
                    HStack {
                        Text("パスワード変更メールを送信")
                        Spacer()
                        Image(systemName: "envelope")
                    }
                    .foregroundColor(.blue)
                }
            }

            Section("退会手続き") {

                VStack(alignment: .leading, spacing: 10) {

                    Text("退会すると、会員アカウントを削除します。")
                        .font(.headline)

                    Text("次の内容が削除されます。")
                        .foregroundColor(.secondary)

                    Text("・会員ページへのログイン情報")
                    Text("・このコミュニティの会員情報")

                    Text("管理者権限を持つアカウントは、この画面から退会（会員情報削除）することはできません。")
                        .font(.headline)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)

                    Text("退会後に再度利用する場合は、新しく会員登録が必要です。")
                        .foregroundColor(.secondary)

                    Text("本人確認のため、会員登録時のパスワードを入力してください。")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }

                HStack {

                    if isDeletePasswordVisible {
                        TextField("会員登録時のパスワード", text: $deletePassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("会員登録時のパスワード", text: $deletePassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Button {
                        isDeletePasswordVisible.toggle()
                    } label: {
                        Image(systemName: isDeletePasswordVisible ? "eye.slash" : "eye")
                            .foregroundColor(.blue)
                    }
                }

                Button(role: .destructive) {

                    let password = deletePassword
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !password.isEmpty else {
                        message = "退会するには、会員登録時のパスワードを入力してください。"
                        return
                    }

                    checkAdminBeforeShowingDeleteAlert()

                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("退会する（会員情報削除）")
                    }
                }
                .disabled(isLoading)
            }

            if !message.isEmpty {
                Section("結果") {
                    Text(message)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("セキュリティ設定")
        .alert(
            "この端末のログイン情報を削除しますか？",
            isPresented: $showClearLoginAlert
        ) {
            Button("キャンセル", role: .cancel) {}

            Button("削除", role: .destructive) {
                clearLoginInfo()
            }

        } message: {
            Text("会員登録は削除されません。次回は手動でログインしてください。")
        }
        .alert(
            "退会してアカウントを削除しますか？",
            isPresented: $showDeleteAccountAlert
        ) {
            Button("キャンセル", role: .cancel) {}

            Button("削除する", role: .destructive) {
                deleteAccount()
            }

        } message: {
            Text("会員情報とログインアカウントを削除します。この操作は取り消せません。")
        }
    }

    private func clearLoginInfo() {

        faceIDAutoLoginEnabled = false
        MemberSavedLoginStore.shared.clear()

        UserDefaults.standard.removeObject(forKey: "savedMemberEmail")
        UserDefaults.standard.removeObject(forKey: "savedMemberPassword")

        do {
            try Auth.auth().signOut()
            message = "この端末のログイン情報を削除しました。もう一度ログインしてください。"
        } catch {
            message = "ログアウトできませんでした：\(error.localizedDescription)"
        }
    }

    private func resetPassword() {

        guard let email = Auth.auth().currentUser?.email,
              !email.isEmpty else {
            message = "ログイン中のメールアドレスを確認できませんでした。"
            return
        }

        Auth.auth().sendPasswordReset(withEmail: email) { error in

            if let error {
                message = "送信できませんでした：\(error.localizedDescription)"
                return
            }

            message = "パスワード変更メールを送信しました。"
        }
    }

    private func checkAdminBeforeShowingDeleteAlert() {

        message = ""

        guard let uid = Auth.auth().currentUser?.uid else {
            message = "ログイン情報を確認できませんでした。"
            return
        }

        let organizationId = organizationStore.organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !organizationId.isEmpty else {
            message = "コミュニティ情報を確認できませんでした。"
            return
        }

        isLoading = true

        db.collection("organizations")
            .document(organizationId)
            .collection("admins")
            .document(uid)
            .getDocument { snapshot, error in

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error {
                        print("管理者確認エラー:", error.localizedDescription)
                        self.message = "退会前の確認に失敗しました。時間をおいてもう一度お試しください。"
                        return
                    }

                    if let data = snapshot?.data(),
                       snapshot?.exists == true {

                        let isActive = data["isActive"] as? Bool ?? false

                        if isActive {
                            self.message = "このアカウントには管理者権限があるため、会員アプリから退会できません。先に管理者権限を別の管理者へ移行してください。"
                            return
                        }
                    }

                    self.showDeleteAccountAlert = true
                }
            }
    }

    private func deleteAccount() {

        message = ""

        let password = deletePassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !password.isEmpty else {
            message = "退会するには、会員登録時のパスワードを入力してください。"
            return
        }

        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            message = "ログイン情報を確認できませんでした。"
            return
        }

        let organizationId = organizationStore.organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !organizationId.isEmpty else {
            message = "コミュニティ情報を確認できませんでした。"
            return
        }

        isLoading = true

        let credential = EmailAuthProvider.credential(
            withEmail: email,
            password: password
        )

        user.reauthenticate(with: credential) { _, error in

            if let error {
                isLoading = false
                message = "パスワード確認に失敗しました。会員登録時のパスワードを確認してください。"
                print(error.localizedDescription)
                return
            }

            deleteFirestoreData(
                organizationId: organizationId,
                uid: user.uid
            ) { firestoreError in

                isLoading = false

                if let firestoreError {
                    message = "退会処理に失敗しました：\(firestoreError.localizedDescription)"
                    return
                }

                faceIDAutoLoginEnabled = false
                MemberSavedLoginStore.shared.clear()

                UserDefaults.standard.removeObject(forKey: "savedMemberEmail")
                UserDefaults.standard.removeObject(forKey: "savedMemberPassword")
                UserDefaults.standard.removeObject(forKey: "memberName")

                deletePassword = ""

                do {
                    try Auth.auth().signOut()
                } catch {
                    print("退会後ログアウト失敗:", error.localizedDescription)
                }

                message = "退会処理が完了しました。ご利用ありがとうございました。"

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            }
        }
    }

    private func deleteFirestoreData(
        organizationId: String,
        uid: String,
        completion: @escaping (Error?) -> Void
    ) {

        let batch = db.batch()

        let memberRef = db.collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)

        let registrationRef = db.collection("organizations")
            .document(organizationId)
            .collection("memberRegistrations")
            .document(uid)

        batch.deleteDocument(memberRef)
        batch.deleteDocument(registrationRef)

        batch.commit { error in
            completion(error)
        }
    }
}
