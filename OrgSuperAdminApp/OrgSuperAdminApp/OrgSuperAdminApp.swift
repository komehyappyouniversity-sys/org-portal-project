import SwiftUI
import FirebaseCore

@main
struct OrgSuperAdminApp: App {

    init() {
        FirebaseApp.configure()
        print("✅ Firebase configured for OrgSuperAdminApp")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
