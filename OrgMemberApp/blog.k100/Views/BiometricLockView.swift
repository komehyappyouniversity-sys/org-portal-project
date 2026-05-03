import SwiftUI

struct BiometricLockView: View {
    @EnvironmentObject var securityStore: MemberSecurityStore

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("会員機能はロックされています")
                .font(.title2.bold())

            Text("Face ID認証を行うと会員ページを開けます。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if !securityStore.errorMessage.isEmpty {
                Text(securityStore.errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                securityStore.authenticate()
            } label: {
                HStack(spacing: 10) {
                    if securityStore.isAuthenticating {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(securityStore.isAuthenticating ? "認証中..." : "Face IDで開く")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .disabled(securityStore.isAuthenticating)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .navigationTitle("会員認証")
        .navigationBarTitleDisplayMode(.inline)
    }
}
