import SwiftUI

struct MemberAppRootView: View {

    @EnvironmentObject var organizationStore: OrganizationStore
    @EnvironmentObject var memberStore: MemberStore
    @EnvironmentObject var securityStore: MemberSecurityStore
    @EnvironmentObject var featureStore: MemberFeatureStore

    @Environment(\.scenePhase) private var scenePhase

    @State private var didStart = false

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

                        Button("団体コードを再設定") {
                            resetOrganizationSelection()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()

                } else if !organizationStore.hasSelection {
                    MemberOrganizationSelectionView()
                        .environmentObject(organizationStore)
                        .environmentObject(featureStore)

                } else if !securityStore.isUnlocked {
                    BiometricLockView()
                        .environmentObject(securityStore)
                        .onAppear {
                            securityStore.authenticateIfNeededOnFirstEntry()
                        }

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
            guard !didStart else { return }
            didStart = true
            startApp()
        }
        .onChange(of: scenePhase) { _, newPhase in
            securityStore.handleScenePhaseChange(to: newPhase)
        }
    }

    private func startApp() {
        print("📱 MemberAppRootView opened")

        memberStore.ensureSignedIn()
        organizationStore.restoreFromLocal()

        if !organizationStore.organizationId.isEmpty {
            print("🏢 organizationId:", organizationStore.organizationId)

            featureStore.startListening(
                organizationId: organizationStore.organizationId
            )
        }
    }

    private func resetOrganizationSelection() {
        print("♻️ reset organization selection")

        featureStore.stopListening()
        organizationStore.clearSelection()
    }
}
