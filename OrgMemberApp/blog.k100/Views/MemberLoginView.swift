import SwiftUI
import FirebaseAuth

struct MemberLoginView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 28) {

                Spacer().frame(height: 40)

                Text("ログイン")
                    .font(.largeTitle.bold())

                VStack(spacing: 16) {

                    Text("登録済みのメールアドレスとパスワードでログインしてください。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    TextField("メールアドレス", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("パスワード", text: $password)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        login()
                    } label: {
                        HStack {
                            Spacer()

                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("ログイン")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }

                            Spacer()
                        }
                        .frame(height: 52)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)

                    Button {
                        resetPassword()
                    } label: {
                        Text("パスワードを忘れた方はこちら")
                            .font(.footnote)
                            .foregroundColor(.blue)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }

                    if !successMessage.isEmpty {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(radius: 4)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .navigationTitle("ログイン")
    }

    private func login() {
        errorMessage = ""
        successMessage = ""

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください"
            return
        }

        isLoading = true

        try? Auth.auth().signOut()

        Auth.auth().signIn(withEmail: trimmedEmail, password: password) { result, error in
            isLoading = false

            if let error {
                let nsError = error as NSError
                errorMessage = convertError(nsError)
                return
            }

            if result?.user != nil {
                successMessage = "ログイン成功"

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
    }

    private func resetPassword() {
        errorMessage = ""
        successMessage = ""

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            errorMessage = "メールアドレスを入力してください"
            return
        }

        Auth.auth().sendPasswordReset(withEmail: trimmedEmail) { error in
            if let error {
                let nsError = error as NSError
                errorMessage = convertError(nsError)
                return
            }

            successMessage = "リセットメールを送信しました"
        }
    }

    private func convertError(_ error: NSError) -> String {
        guard let code = AuthErrorCode(rawValue: error.code) else {
            return error.localizedDescription
        }

        switch code {
        case .wrongPassword:
            return "パスワードが違います"

        case .userNotFound:
            return "このメールアドレスは登録されていません"

        case .invalidEmail:
            return "メールアドレスの形式が正しくありません"

        case .networkError:
            return "通信エラーが発生しました"

        case .invalidCredential:
            return "メールアドレスまたはパスワードが正しくありません"

        default:
            return error.localizedDescription
        }
    }
}
