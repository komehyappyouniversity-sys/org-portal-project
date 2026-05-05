import SwiftUI

struct ContentView: View {
    @StateObject private var authStore = SuperAdminAuthStore()
    @StateObject private var securityStore = SuperAdminSecurityStore()

    var body: some View {
        Group {
            if authStore.isSignedIn && authStore.isSuperAdmin {
                if securityStore.isUnlocked {
                    OrganizationListView()
                        .environmentObject(authStore)
                } else {
                    VStack(spacing: 20) {
                        Text("上位管理アプリ")
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
                    .onAppear {
                        securityStore.unlockWithFaceID()
                    }
                }
            } else {
                SuperAdminLoginView()
                    .environmentObject(authStore)
            }
        }
        .onAppear {
            authStore.start()
        }
    }
}
