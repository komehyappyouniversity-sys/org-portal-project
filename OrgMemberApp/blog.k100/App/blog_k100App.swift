import SwiftUI
import FirebaseCore

@main
struct blog_k100App: App {

    // 🔥 これが重要（AppDelegateを有効化）
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var organizationStore = OrganizationStore()
    @StateObject private var memberStore = MemberStore()
    @StateObject private var securityStore = MemberSecurityStore()

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
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
