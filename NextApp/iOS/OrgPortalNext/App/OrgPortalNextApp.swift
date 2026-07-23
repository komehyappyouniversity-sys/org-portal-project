import SwiftData
import SwiftUI
import DataLayer
import FeatureTools
import Navigation
import Notifications

@main
struct OrgPortalNextApp: App {
    private let modelContainer: ModelContainer

    init() {
        let projectId = Bundle.main.object(forInfoDictionaryKey: "FirebaseProjectID") as? String ?? ""
        let firebaseConfiguration = FirebaseRuntimeConfiguration(
            environment: .emulator,
            projectId: projectId,
            isDebugBuild: true,
            productionProjectId: "ictnagaoka-member"
        )
        do {
            try firebaseConfiguration.validate()
        } catch {
            fatalError("安全のため起動を停止しました。Debugビルドは本番Firebaseへ接続できません。")
        }

        do {
            modelContainer = try ModelContainer(for: ScheduleRecord.self)
        } catch {
            fatalError("Unable to initialize local storage: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppBootstrapView(modelContainer: modelContainer)
        }
        .modelContainer(modelContainer)
    }
}

private struct AppBootstrapView: View {
    @StateObject private var scheduleModel: ScheduleFeatureModel

    init(modelContainer: ModelContainer) {
        let repository = SwiftDataScheduleRepository(modelContainer: modelContainer)
        let notifications = UserNotificationScheduler()
        _scheduleModel = StateObject(
            wrappedValue: ScheduleFeatureModel(
                repository: repository,
                notificationScheduler: notifications
            )
        )
    }

    var body: some View {
        AppShellView(
            home: GuestHomeView(model: scheduleModel),
            tools: ScheduleListView(model: scheduleModel),
            community: PlaceholderTabView(
                titleKey: "tab.community",
                messageKey: "placeholder.community"
            ),
            profile: PlaceholderTabView(
                titleKey: "tab.profile",
                messageKey: "placeholder.profile"
            )
        )
    }
}
