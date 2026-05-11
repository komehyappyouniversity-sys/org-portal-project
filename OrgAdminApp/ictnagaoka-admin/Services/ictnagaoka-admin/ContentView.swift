import SwiftUI

struct ContentView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @EnvironmentObject var authStore: AdminAuthStore
    @EnvironmentObject var featureStore: AdminFeatureStore

    @StateObject private var securityStore = AdminSecurityStore()

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        if authStore.isSignedIn {
            if securityStore.isUnlocked {
                AdminDashboardView()
                    .environmentObject(organizationStore)
                    .environmentObject(authStore)
                    .environmentObject(featureStore)
            } else {
                lockView
            }
        } else {
            AdminLoginView()
                .environmentObject(authStore)
                .environmentObject(organizationStore)
        }
    }

    private var lockView: some View {
        VStack(spacing: 20) {
            Text("管理アプリ")
                .font(.largeTitle.bold())

            Text("Face IDで認証してください")
                .foregroundColor(.gray)

            Button("Face IDで開く") {
                securityStore.unlockWithFaceID()
            }
            .buttonStyle(.borderedProminent)

            if !securityStore.errorMessage.isEmpty {
                Text(securityStore.errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
        }
        .padding()
    }
}
