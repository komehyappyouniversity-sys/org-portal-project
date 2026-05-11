import SwiftUI

struct ContentView: View {

    @EnvironmentObject var organizationStore: OrganizationStore
    @EnvironmentObject var memberStore: MemberStore
    @EnvironmentObject var securityStore: MemberSecurityStore
    @EnvironmentObject var featureStore: MemberFeatureStore

    var body: some View {
        NavigationStack {
            Group {
                if organizationStore.isLoading || memberStore.isLoading {

                    VStack(spacing: 16) {
                        ProgressView()

                        Text("起動中...")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if let errorMessage = organizationStore.errorMessage,
                          !errorMessage.isEmpty {

                    VStack(spacing: 16) {

                        Text("起動エラー")
                            .font(.title2.bold())

                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)

                        Button("再読み込み") {
                            startApp()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()

                } else {

                    MemberHomeView()
                        .environmentObject(memberStore)
                        .environmentObject(organizationStore)
                        .environmentObject(securityStore)
                        .environmentObject(featureStore)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            startApp()
        }
    }

    private func startApp() {

        print("📱 ContentView opened")

        memberStore.ensureSignedIn()

        organizationStore.startListening(
            organizationId: OrganizationConfig.organizationId
        )

        featureStore.startListening(
            organizationId: OrganizationConfig.organizationId
        )
    }
}
