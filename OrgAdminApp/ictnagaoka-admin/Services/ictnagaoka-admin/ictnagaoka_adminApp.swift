import SwiftUI
import FirebaseCore

@main
struct ictnagaoka_adminApp: App {

    @StateObject private var organizationStore = AdminOrganizationStore()
    @StateObject private var authStore = AdminAuthStore()
    @StateObject private var featureStore = AdminFeatureStore()

    init() {
        FirebaseApp.configure()
        print("✅ Firebase configured for ictnagaoka-admin")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(organizationStore)
                .environmentObject(authStore)
                .environmentObject(featureStore)
        }
    }
}
