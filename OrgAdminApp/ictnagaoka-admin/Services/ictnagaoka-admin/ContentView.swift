import SwiftUI

struct ContentView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @EnvironmentObject var authStore: AdminAuthStore
    @EnvironmentObject var featureStore: AdminFeatureStore

    @StateObject private var securityStore = AdminSecurityStore()

    var body: some View {
        contentView
    }

    @ViewBuilder
    private var contentView: some View {

        if authStore.isSignedIn {

            if securityStore.isUnlocked {

                AdminDashboardView()
                    .environmentObject(organizationStore)
                    .environmentObject(authStore)
                    .environmentObject(featureStore)

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
}
