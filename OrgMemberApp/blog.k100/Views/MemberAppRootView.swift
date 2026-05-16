import SwiftUI

struct MemberAppRootView: View {

    @EnvironmentObject var organizationStore: OrganizationStore
    @EnvironmentObject var memberStore: MemberStore
    @EnvironmentObject var securityStore: MemberSecurityStore
    @EnvironmentObject var featureStore: MemberFeatureStore

    @Environment(\.scenePhase) private var scenePhase

    @State private var didStart = false

    private let selectedOrganizationIdKey = "selectedOrganizationId"

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

                } else if organizationStore.organizationId.isEmpty {
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
        .onChange(of: organizationStore.organizationId) { _, newOrganizationId in
            handleOrganizationIdChanged(newOrganizationId)
        }
        .onChange(of: scenePhase) { _, newPhase in
            securityStore.handleScenePhaseChange(to: newPhase)
        }
    }

    private func startApp() {
        print("📱 MemberAppRootView opened")

        memberStore.ensureSignedIn()

        let savedOrganizationId = UserDefaults.standard
            .string(forKey: selectedOrganizationIdKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !savedOrganizationId.isEmpty else {
            print("🏢 saved organizationId なし")
            organizationStore.reset()
            return
        }

        print("🏢 saved organizationId:", savedOrganizationId)

        organizationStore.startListening(
            organizationId: savedOrganizationId
        )

        featureStore.startListening(
            organizationId: savedOrganizationId
        )
    }

    private func handleOrganizationIdChanged(_ organizationId: String) {
        let safeOrganizationId = organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !safeOrganizationId.isEmpty else {
            return
        }

        UserDefaults.standard.set(
            safeOrganizationId,
            forKey: selectedOrganizationIdKey
        )

        featureStore.startListening(
            organizationId: safeOrganizationId
        )

        print("✅ organizationId saved:", safeOrganizationId)
    }

    private func resetOrganizationSelection() {
        print("♻️ reset organization selection")

        featureStore.stopListening()

        UserDefaults.standard.removeObject(
            forKey: selectedOrganizationIdKey
        )

        organizationStore.reset()
    }
}
