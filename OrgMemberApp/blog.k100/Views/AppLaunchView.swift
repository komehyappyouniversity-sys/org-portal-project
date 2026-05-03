import SwiftUI

struct AppLaunchView: View {
    @StateObject private var organizationStore = OrganizationStore()
    @StateObject private var securityStore = MemberSecurityStore()

    var body: some View {
        Group {
            if organizationStore.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("起動中...")
                }
            } else if let error = organizationStore.errorMessage, !error.isEmpty {
                VStack(spacing: 16) {
                    Text("起動エラー")
                        .font(.title2.bold())

                    Text(error)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)

                    Button("再読み込み") {
                        organizationStore.startListening(
                            organizationId: OrganizationConfig.organizationId
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ContentView()
                    .environmentObject(organizationStore)
                    .environmentObject(securityStore)
            }
        }
        .onAppear {
            if organizationStore.organizationId.isEmpty {
                organizationStore.startListening(
                    organizationId: OrganizationConfig.organizationId
                )
            }
        }
    }
}
