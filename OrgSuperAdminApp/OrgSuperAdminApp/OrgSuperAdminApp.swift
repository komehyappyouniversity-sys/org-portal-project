import SwiftUI
import FirebaseCore

@main
struct OrgSuperAdminApp: App {

    @StateObject private var featureStore = AdminFeatureStore()

    init() {
        FirebaseApp.configure()
        print("✅ Firebase configured for OrgSuperAdminApp")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(featureStore)
        }
    }
}
