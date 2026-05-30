import SwiftUI
import FirebaseAuth

struct SecuritySettingsView: View {

    @AppStorage("faceIDAutoLoginEnabled")
    private var faceIDAutoLoginEnabled = true

    @State private var showDeleteAlert = false
    @State private var message = ""

    var body: some View {

        List {

            Section("Face ID") {
                Toggle(
                    "Face ID自動ログイン",
                    isOn: $faceIDAutoLoginEnabled
                )
            }

            Section("自動ログイン") {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Text("この端末の自動ログインを解除")
                        .foregroundColor(.red)
                }
            }

            Section("会員アカウント") {
                Button {
                    resetPassword()
                } label: {
                    Text("ログインパスワードを変更")
                        .foregroundColor(.blue)
                }
            }

            if !message.isEmpty {
                Section("結果") {
                    Text(message)
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("セキュリティ設定")
        .alert(
            "この端末の自動ログインを解除しますか？",
            isPresented: $showDeleteAlert
        ) {
            Button("キャンセル", role: .cancel) { }

            Button("解除", role: .destructive) {
                MemberSavedLoginStore.shared.clear()
                message = "この端末の自動ログインを解除しました"
            }

        } message: {
            Text("次回からメールアドレスとパスワードの入力が必要になります。")
        }
    }

    private func resetPassword() {

        guard let email = Auth.auth().currentUser?.email else {
            message = "ログイン中のメールアドレスが取得できません"
            return
        }

        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error {
                message = error.localizedDescription
                return
            }

            message = "登録メールアドレスへパスワード変更メールを送信しました"
        }
    }
}
