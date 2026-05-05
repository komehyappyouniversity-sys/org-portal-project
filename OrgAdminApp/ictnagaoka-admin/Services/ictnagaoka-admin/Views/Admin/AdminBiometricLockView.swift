import SwiftUI
import Combine

struct AdminBiometricLockView: View {
    @EnvironmentObject private var securityStore: AdminSecurityStore

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("管理アプリ")
                .font(.title.bold())

            Text("Face IDでロックを解除してください")
                .foregroundColor(.secondary)

            if let errorMessage = securityStore.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                print("🔐 Face ID button tapped")
                securityStore.authenticate()
            } label: {
                Text("Face IDで開く")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            securityStore.authenticate()
        }
    }
}
