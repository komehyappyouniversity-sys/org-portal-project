import SwiftUI

struct AdminLoginView: View {
    @EnvironmentObject var authStore: AdminAuthStore

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                headerView

                VStack(spacing: 16) {
                    emailField
                    passwordField
                }

                if let errorMessage = authStore.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                loginButton

                if authStore.isLoading {
                    ProgressView("ログイン中...")
                        .padding(.top, 8)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("管理者ログイン")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerView: some View {
        VStack(spacing: 10) {
            Text("管理アプリ")
                .font(.system(size: 30, weight: .bold))

            Text("メールアドレスとパスワードでログインしてください")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("メールアドレス")
                .font(.headline)

            TextField("example@email.com", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("パスワード")
                .font(.headline)

            HStack {
                Group {
                    if showPassword {
                        TextField("パスワード", text: $password)
                    } else {
                        SecureField("パスワード", text: $password)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }

    private var loginButton: some View {
        Button {
            Task {
                await authStore.signIn(email: email, password: password)
            }
        } label: {
            Text(authStore.isLoading ? "ログイン中..." : "ログイン")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(authStore.isLoading ? Color.gray : Color.blue)
                .cornerRadius(12)
        }
        .disabled(authStore.isLoading)
    }
}
