import SwiftUI
import FirebaseCore
import Combine

@main
struct ictnagaoka_adminApp: App {
    @StateObject private var organizationStore = OrganizationStore()
    @StateObject private var authStore = AdminAuthStore()
    @StateObject private var securityStore = AdminSecurityStore()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authStore.isSignedIn && authStore.isAdminApproved {
                    if securityStore.isUnlocked {
                        AdminDashboardView()
                            .environmentObject(organizationStore)
                            .environmentObject(authStore)
                            .environmentObject(securityStore)
                            .onAppear {
                                organizationStore.startListening(
                                    organizationId: OrganizationConfig.organizationId
                                )
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
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .background {
                    securityStore.lock()
                }
            }
        }
    }
}
