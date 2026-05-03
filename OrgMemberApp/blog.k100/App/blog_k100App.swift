import SwiftUI
import FirebaseCore

@main
struct blog_k100App: App {
    @StateObject private var organizationStore = OrganizationStore()
    @StateObject private var memberStore = MemberStore()
    @StateObject private var securityStore = MemberSecurityStore()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(organizationStore)
                .environmentObject(memberStore)
                .environmentObject(securityStore)
        }
    }
}
