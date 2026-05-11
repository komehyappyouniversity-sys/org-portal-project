import SwiftUI

struct ContentView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @EnvironmentObject var authStore: AdminAuthStore
    @EnvironmentObject var featureStore: AdminFeatureStore

    @StateObject private var securityStore = AdminSecurityStore()

    @State private var isCheckingOrganization = true
    @State private var hasOrganizationSelection = false
    @State private var selectedOrganizationId = ""

    private let organizationService = OrganizationService()

    var body: some View {
        contentView
            .onAppear {
                loadLocalOrganizationSelection()
            }
    }

    @ViewBuilder
    private var contentView: some View {

        if authStore.isSignedIn {

            if securityStore.isUnlocked {

                if isCheckingOrganization {

                    VStack(spacing: 16) {
                        ProgressView()
                        Text("組織設定を確認中...")
                            .foregroundColor(.gray)
                    }

                } else if hasOrganizationSelection {

                    AdminDashboardView()
                        .environmentObject(organizationStore)
                        .environmentObject(authStore)
                        .environmentObject(featureStore)

                } else {

                    OrganizationSelectionView { organization in
                        selectedOrganizationId = organization.id
                        hasOrganizationSelection = true

                        organizationStore.startListening(
                            organizationId: organization.id
                        )

                        featureStore.startListening(
                            organizationId: organization.id
                        )
                    }
                }

            } else {

                AdminBiometricLockView()
                    .environmentObject(securityStore)

            }

        } else {

            AdminLoginView()
                .environmentObject(authStore)
                .environmentObject(organizationStore)
        }
    }

    private func loadLocalOrganizationSelection() {
        guard authStore.isSignedIn else {
            isCheckingOrganization = false
            hasOrganizationSelection = false
            selectedOrganizationId = ""
            return
        }

        do {
            if let selection = try organizationService.loadLocalOrganizationSelection() {
                selectedOrganizationId = selection.organizationId
                hasOrganizationSelection = true

                organizationStore.startListening(
                    organizationId: selection.organizationId
                )

                featureStore.startListening(
                    organizationId: selection.organizationId
                )

                print("✅ 保存済み組織で起動:", selection.organizationId)

            } else {
                hasOrganizationSelection = false
                selectedOrganizationId = ""
                print("ℹ️ 保存済み組織なし。組織コード入力へ。")
            }

        } catch {
            hasOrganizationSelection = false
            selectedOrganizationId = ""
            print("❌ 保存済み組織の読み込み失敗:", error.localizedDescription)
        }

        isCheckingOrganization = false
    }
}
