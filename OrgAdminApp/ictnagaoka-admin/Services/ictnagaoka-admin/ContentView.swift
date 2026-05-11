import SwiftUI

struct ContentView: View {

    @EnvironmentObject var organizationStore: OrganizationStore
    @EnvironmentObject var authStore: AdminAuthStore
    @EnvironmentObject var featureStore: AdminFeatureStore

    @StateObject private var securityStore = AdminSecurityStore()

    var body: some View {

        NavigationStack {

            if authStore.isSignedIn {

                signedInView

            } else {

                AdminLoginView()
                    .environmentObject(authStore)
                    .environmentObject(organizationStore)
            }
        }
    }

    // MARK: - Signed In View

    @ViewBuilder
    private var signedInView: some View {

        if securityStore.isUnlocked {

            AdminDashboardView()

        } else {

            faceIDView
        }
    }

    // MARK: - Face ID View

    private var faceIDView: some View {

        VStack(spacing: 20) {

            Text("管理アプリ")
                .font(.largeTitle.bold())

            Text("Face IDで認証してください")
                .foregroundColor(.gray)

            Button("Face IDで開く") {

                securityStore.authenticate()
            }
            .buttonStyle(.borderedProminent)

            if let errorMessage = securityStore.errorMessage,
               !errorMessage.isEmpty {

                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()

        .onAppear {

            securityStore.authenticate()
        }
    }
}
