import SwiftUI
import FirebaseCore

@main
struct blog_k100App: App {

    @StateObject private var organizationStore = OrganizationStore()
    @StateObject private var memberStore = MemberStore()
    @StateObject private var securityStore = MemberSecurityStore()
    @StateObject private var featureStore = MemberFeatureStore()

    init() {
        FirebaseApp.configure()
        print("✅ Firebase configured for member app")
    }

    var body: some Scene {
        WindowGroup {
            MemberAppRootView()
                .environmentObject(organizationStore)
                .environmentObject(memberStore)
                .environmentObject(securityStore)
                .environmentObject(featureStore)
        }
    }
}
