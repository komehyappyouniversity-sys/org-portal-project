import SwiftData
import SwiftUI
import DataLayer
import FeatureTools
import Navigation
import Notifications
import Model
import Session

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
                MeetingMinutesRecord.self,
                SnsCustomLinkRecord.self,
                FavoriteBookmarkRecord.self
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
    @StateObject private var snsPostingAssistantModel: SnsPostingAssistantFeatureModel
    @StateObject private var favoriteBookmarkModel: FavoriteBookmarkFeatureModel
    @StateObject private var appSession: AppSession
    @StateObject private var accountModel: AccountFeatureModel

    init(modelContainer: ModelContainer) {
        let session = AppSession()
        _appSession = StateObject(wrappedValue: session)
        _accountModel = StateObject(
            wrappedValue: AccountFeatureModel(
                repository: UnavailableAccountAuthRepository(),
                session: session
            )
        )
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
        _snsPostingAssistantModel = StateObject(
            wrappedValue: SnsPostingAssistantFeatureModel(
                repository: SwiftDataSnsCustomLinkRepository(
                    modelContainer: modelContainer
                )
            )
        )
        _favoriteBookmarkModel = StateObject(
            wrappedValue: FavoriteBookmarkFeatureModel(
                repository: SwiftDataFavoriteBookmarkRepository(
                    modelContainer: modelContainer
                )
            )
        )
    }

    var body: some View {
        AppShellView(
            home: GuestHomeView(
                scheduleModel: scheduleModel,
                diaryModel: diaryModel,
                cashDistributionModel: cashDistributionModel,
                meetingMinutesModel: meetingMinutesModel,
                favoriteBookmarkModel: favoriteBookmarkModel
            ),
            tools: ToolsHubView(
                scheduleModel: scheduleModel,
                diaryModel: diaryModel,
                cashDistributionModel: cashDistributionModel,
                meetingMinutesModel: meetingMinutesModel,
                snsPostingAssistantModel: snsPostingAssistantModel,
                favoriteBookmarkModel: favoriteBookmarkModel
            ),
            community: PlaceholderTabView(
                titleKey: "tab.community",
                messageKey: "placeholder.community"
            ),
            profile: AccountRootView(model: accountModel)
        )
    }
}

@MainActor
private final class AccountFeatureModel: ObservableObject {
    enum Screen {
        case overview
        case register
        case login
        case resetPassword
    }

    @Published var screen: Screen = .overview
    @Published var isLoading = false
    @Published var message: String?
    @Published private(set) var accessState: AccountAccessState = .guest

    private let repository: any AccountAuthRepository
    private let session: AppSession

    init(repository: any AccountAuthRepository, session: AppSession) {
        self.repository = repository
        self.session = session
    }

    func show(_ screen: Screen) {
        self.screen = screen
        message = nil
    }

    func register(email: String, password: String, confirmation: String) {
        let credentials = AccountCredentials(
            email: email,
            password: password,
            passwordConfirmation: confirmation
        )
        guard validate(credentials) else { return }
        authenticate { try await self.repository.register(credentials: credentials) }
    }

    func login(email: String, password: String) {
        let credentials = AccountCredentials(email: email, password: password)
        guard validate(credentials) else { return }
        authenticate { try await self.repository.login(credentials: credentials) }
    }

    func resetPassword(email: String) {
        let credentials = AccountCredentials(email: email, password: "password")
        guard validate(credentials) else { return }
        isLoading = true
        message = nil
        Task {
            do {
                try await repository.sendPasswordReset(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                isLoading = false
                message = "パスワード再設定メールを送信しました。"
            } catch {
                show(error)
            }
        }
    }

    private func validate(_ credentials: AccountCredentials) -> Bool {
        if let validationMessage = credentials.validationMessage() {
            message = validationMessage
            return false
        }
        return true
    }

    private func authenticate(
        _ operation: @escaping @MainActor () async throws -> AuthenticatedAccount
    ) {
        isLoading = true
        message = nil
        Task {
            do {
                let account = try await operation()
                session.updateUserStage(.member)
                accessState = .member
                isLoading = false
                message = "\(account.email)でログインしました。"
                screen = .overview
            } catch {
                show(error)
            }
        }
    }

    private func show(_ error: Error) {
        isLoading = false
        message = error.localizedDescription
    }
}

private struct AccountRootView: View {
    @ObservedObject var model: AccountFeatureModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch model.screen {
                    case .overview:
                        overview
                    case .register:
                        AccountFormView(model: model, isRegistration: true)
                    case .login:
                        AccountFormView(model: model, isRegistration: false)
                    case .resetPassword:
                        PasswordResetView(model: model)
                    }
                }
                .padding(24)
            }
            .navigationTitle("マイページ")
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch model.accessState {
            case .guest:
                Text("現在はGuestとして利用しています。会員登録後も便利機能を引き続き利用できます。")
                Button("会員登録") { model.show(.register) }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                Button("ログイン") { model.show(.login) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("パスワードを忘れた方") { model.show(.resetPassword) }
                    .buttonStyle(.plain)
            case .pendingApproval:
                Text("コミュニティへの参加申請を確認中です。承認後に会員向け機能が追加されます。")
            case .rejected:
                Text("コミュニティへの参加申請は承認されませんでした。申請先へご確認ください。")
                Button("別のアカウントでログイン") { model.show(.login) }
                    .buttonStyle(.bordered)
            case .member:
                Text("会員としてログインしています。参加中のコミュニティ機能を利用できます。")
            }
            status
        }
    }

    @ViewBuilder
    private var status: some View {
        if model.isLoading {
            ProgressView()
        }
        if let message = model.message {
            Text(message)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AccountFormView: View {
    @ObservedObject var model: AccountFeatureModel
    let isRegistration: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isRegistration ? "会員登録" : "ログイン")
                .font(.title2.bold())
            TextField("メールアドレス", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
            SecureField("パスワード（8文字以上）", text: $password)
                .textFieldStyle(.roundedBorder)
            if isRegistration {
                SecureField("確認用パスワード", text: $confirmation)
                    .textFieldStyle(.roundedBorder)
            }
            Button(isRegistration ? "登録する" : "ログイン") {
                if isRegistration {
                    model.register(email: email, password: password, confirmation: confirmation)
                } else {
                    model.login(email: email, password: password)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isLoading)
            Button("戻る") { model.show(.overview) }
            if model.isLoading { ProgressView() }
            if let message = model.message {
                Text(message).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PasswordResetView: View {
    @ObservedObject var model: AccountFeatureModel
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("パスワード再設定")
                .font(.title2.bold())
            TextField("メールアドレス", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
            Button("再設定メールを送信") { model.resetPassword(email: email) }
                .buttonStyle(.borderedProminent)
                .disabled(model.isLoading)
            Button("戻る") { model.show(.overview) }
            if model.isLoading { ProgressView() }
            if let message = model.message {
                Text(message).foregroundStyle(.secondary)
            }
        }
    }
}
