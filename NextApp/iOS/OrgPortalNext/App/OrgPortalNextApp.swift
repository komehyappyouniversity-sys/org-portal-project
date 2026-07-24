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
            modelContainer = try ModelContainer(
                for: ScheduleRecord.self,
                DiaryRecord.self,
                CashDistributionRecord.self,
                MeetingMinutesRecord.self
            )
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
    @StateObject private var diaryModel: DiaryFeatureModel
    @StateObject private var cashDistributionModel: CashDistributionFeatureModel
    @StateObject private var meetingMinutesModel: MeetingMinutesFeatureModel

    init(modelContainer: ModelContainer) {
        let scheduleRepository = SwiftDataScheduleRepository(
            modelContainer: modelContainer
        )
        let notifications = UserNotificationScheduler()
        _scheduleModel = StateObject(
            wrappedValue: ScheduleFeatureModel(
                repository: scheduleRepository,
                notificationScheduler: notifications
            )
        )
        let diaryRepository = SwiftDataDiaryRepository(
            modelContainer: modelContainer
        )
        let photoStore = LocalDiaryPhotoStore()
        _diaryModel = StateObject(
            wrappedValue: DiaryFeatureModel(
                repository: diaryRepository,
                photoStore: photoStore
            )
        )
        let cashDistributionRepository = SwiftDataCashDistributionRepository(
            modelContainer: modelContainer
        )
        _cashDistributionModel = StateObject(
            wrappedValue: CashDistributionFeatureModel(
                repository: cashDistributionRepository
            )
        )
        let meetingRecordingStore = LocalMeetingRecordingStore()
        _meetingMinutesModel = StateObject(
            wrappedValue: MeetingMinutesFeatureModel(
                repository: SwiftDataMeetingMinutesRepository(
                    modelContainer: modelContainer
                ),
                recordingStore: meetingRecordingStore
            )
        )
    }

    var body: some View {
        AppShellView(
            home: GuestHomeView(
                scheduleModel: scheduleModel,
                diaryModel: diaryModel,
                cashDistributionModel: cashDistributionModel,
                meetingMinutesModel: meetingMinutesModel
            ),
            tools: ToolsHubView(
                scheduleModel: scheduleModel,
                diaryModel: diaryModel,
                cashDistributionModel: cashDistributionModel,
                meetingMinutesModel: meetingMinutesModel
            ),
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
