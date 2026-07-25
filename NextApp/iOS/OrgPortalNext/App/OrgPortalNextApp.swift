import LocalAuthentication
import Security
import SwiftData
import SwiftUI
import VisionKit
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
            environment: .development,
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
    @StateObject private var communityModel: CommunityFeatureModel

    init(modelContainer: ModelContainer) {
        let session = AppSession()
        let firebaseAPIKey = Bundle.main.object(
            forInfoDictionaryKey: "FirebaseWebAPIKey"
        ) as? String ?? ""
        _appSession = StateObject(wrappedValue: session)
        _accountModel = StateObject(
            wrappedValue: AccountFeatureModel(
                repository: FirebaseRESTAccountAuthRepository(
                    apiKey: firebaseAPIKey,
                    projectId: Bundle.main.object(
                        forInfoDictionaryKey: "FirebaseProjectID"
                    ) as? String ?? ""
                ),
                biometricStore: KeychainBiometricCredentialStore(),
                session: session
            )
        )
        _communityModel = StateObject(
            wrappedValue: CommunityFeatureModel(
                repository: FirebaseRESTCommunityRepository(
                    projectId: Bundle.main.object(
                        forInfoDictionaryKey: "FirebaseProjectID"
                    ) as? String ?? ""
                ),
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
            community: CommunityRootView(model: communityModel),
            profile: AccountRootView(model: accountModel)
        )
    }
}

@MainActor
private final class CommunityFeatureModel: ObservableObject {
    @Published var code = ""
    @Published private(set) var candidate: Community?
    @Published private(set) var items: [(CommunityMembership, Community)] = []
    @Published private(set) var isLoading = false
    @Published var message: String?
    @Published var showsScanner = false

    private let repository: any CommunityRepository
    let session: AppSession

    init(repository: any CommunityRepository, session: AppSession) {
        self.repository = repository
        self.session = session
    }

    var isLoggedIn: Bool {
        session.authenticatedUserId != nil && session.authenticationToken != nil
    }

    func search() {
        guard let token = session.authenticationToken else {
            message = "先にマイページからログインしてください。"
            return
        }
        isLoading = true
        message = nil
        Task {
            do {
                candidate = try await repository.findCommunity(code: code, idToken: token)
                isLoading = false
            } catch {
                candidate = nil
                isLoading = false
                message = error.localizedDescription
            }
        }
    }

    func receivedScan(_ value: String) {
        showsScanner = false
        code = CommunityCodeParser.parse(value) ?? value
        search()
    }

    func apply() {
        guard let candidate,
              let userId = session.authenticatedUserId,
              let token = session.authenticationToken else { return }
        isLoading = true
        message = nil
        Task {
            do {
                try await repository.apply(
                    community: candidate,
                    userId: userId,
                    idToken: token
                )
                self.candidate = nil
                message = "参加申請を送信しました。承認されるまでお待ちください。"
                await refresh()
            } catch {
                isLoading = false
                message = error.localizedDescription
            }
        }
    }

    func refresh() async {
        guard let userId = session.authenticatedUserId,
              let token = session.authenticationToken else {
            items = []
            return
        }
        isLoading = true
        do {
            items = try await repository.memberships(userId: userId, idToken: token)
            let approved = items.filter { $0.0.status == .approved }
            if session.selectedCommunityId == nil, let first = approved.first {
                session.selectCommunity(first.1.id)
            }
            session.updateUserStage(approved.isEmpty ? .guest : .member)
            isLoading = false
        } catch {
            isLoading = false
            message = error.localizedDescription
        }
    }
}

private struct CommunityRootView: View {
    @ObservedObject var model: CommunityFeatureModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !model.isLoggedIn {
                        ContentUnavailableView(
                            "ログインが必要です",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text("マイページで会員登録またはログイン後に参加申請できます。")
                        )
                    } else {
                        membershipSection
                        joinSection
                    }
                    if model.isLoading { ProgressView() }
                    if let message = model.message {
                        Text(message).foregroundStyle(.secondary)
                    }
                }
                .padding(24)
            }
            .navigationTitle("つながる")
            .task { await model.refresh() }
            .sheet(isPresented: $model.showsScanner) {
                CommunityQRScanner { model.receivedScan($0) }
            }
        }
    }

    private var membershipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("参加コミュニティ").font(.title2.bold())
                Spacer()
                Button("更新") { Task { await model.refresh() } }
            }
            if model.items.isEmpty {
                Text("参加申請はまだありません。").foregroundStyle(.secondary)
            }
            ForEach(Array(model.items.enumerated()), id: \.element.0.id) { _, item in
                let (membership, community) = item
                HStack(spacing: 12) {
                    CommunityLogo(community: community)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(community.name).font(.headline)
                        Text(statusText(membership.status))
                            .foregroundStyle(statusColor(membership.status))
                    }
                    Spacer()
                    if membership.status == .approved {
                        Button(
                            model.session.selectedCommunityId == community.id ? "選択中" : "切替"
                        ) {
                            model.session.selectCommunity(community.id)
                        }
                        .disabled(model.session.selectedCommunityId == community.id)
                    }
                }
                .padding()
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            if model.session.previousCommunityId != nil {
                Button("前のコミュニティへ戻る") {
                    model.session.returnToPreviousCommunity()
                }
            }
        }
    }

    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("コミュニティへ参加").font(.title2.bold())
            TextField("コミュニティコード", text: $model.code)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("コードを確認") { model.search() }
                    .buttonStyle(.borderedProminent)
                Button("QRコードを読む") { model.showsScanner = true }
                    .buttonStyle(.bordered)
            }
            if let community = model.candidate {
                VStack(alignment: .leading, spacing: 10) {
                    CommunityLogo(community: community)
                    Text(community.name).font(.headline)
                    if !community.description.isEmpty { Text(community.description) }
                    if let homepage = community.homepageURL {
                        Link("ホームページを見る", destination: homepage)
                    }
                    Button("このコミュニティへ参加申請") { model.apply() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func statusText(_ status: CommunityMembershipStatus) -> String {
        switch status {
        case .pending: "承認待ち"
        case .approved: "参加中"
        case .rejected: "承認されませんでした"
        }
    }

    private func statusColor(_ status: CommunityMembershipStatus) -> Color {
        switch status {
        case .pending: .orange
        case .approved: .green
        case .rejected: .red
        }
    }
}

private struct CommunityLogo: View {
    let community: Community

    var body: some View {
        AsyncImage(url: community.logoURL) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Image(systemName: "person.3.fill").foregroundStyle(.secondary)
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct CommunityQRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(
        _ uiViewController: DataScannerViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard case .barcode(let barcode) = addedItems.first,
                  let value = barcode.payloadStringValue else { return }
            onCode(value)
        }
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
    @Published private(set) var canUseBiometricLogin = false

    private let repository: any AccountAuthRepository
    private let biometricStore: any BiometricCredentialStore
    private let session: AppSession

    init(
        repository: any AccountAuthRepository,
        biometricStore: any BiometricCredentialStore,
        session: AppSession
    ) {
        self.repository = repository
        self.biometricStore = biometricStore
        self.session = session
        canUseBiometricLogin = biometricStore.hasCredential
    }

    func show(_ screen: Screen) {
        self.screen = screen
        message = nil
    }

    func register(
        name: String,
        furigana: String,
        email: String,
        password: String,
        confirmation: String
    ) {
        let credentials = AccountCredentials(
            email: email,
            password: password,
            passwordConfirmation: confirmation,
            name: name,
            furigana: furigana
        )
        guard validate(credentials) else { return }
        authenticate { try await self.repository.register(credentials: credentials) }
    }

    func login(email: String, password: String) {
        let credentials = AccountCredentials(email: email, password: password)
        guard validate(credentials) else { return }
        authenticate { try await self.repository.login(credentials: credentials) }
    }

    func biometricLogin() {
        authenticate {
            let refreshToken = try await self.biometricStore.load()
            return try await self.repository.refresh(refreshToken: refreshToken)
        }
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
                session.updateUserStage(.guest)
                session.updateAuthenticatedUser(
                    userId: account.userId,
                    idToken: account.idToken
                )
                do {
                    try biometricStore.save(account.refreshToken)
                    canUseBiometricLogin = true
                } catch {
                    canUseBiometricLogin = biometricStore.hasCredential
                }
                accessState = account.emailVerified ? .registered : .guest
                isLoading = false
                message = account.emailVerified
                    ? "\(account.email)でログインしました。「つながる」からコミュニティへ参加できます。"
                    : "確認メールを送信しました。メール内のリンクで確認後、ログインしてください。"
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
                if model.canUseBiometricLogin {
                    Button("Face IDでログイン") { model.biometricLogin() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
                Button("パスワードを忘れた方") { model.show(.resetPassword) }
                    .buttonStyle(.plain)
            case .pendingApproval:
                Text("コミュニティへの参加申請を確認中です。承認後に会員向け機能が追加されます。")
            case .registered:
                Text("ログイン済みです。「つながる」からコミュニティコードまたはQRコードで参加申請できます。")
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

private protocol BiometricCredentialStore: Sendable {
    var hasCredential: Bool { get }
    func save(_ refreshToken: String) throws
    func load() async throws -> String
}

private enum BiometricCredentialError: LocalizedError {
    case unavailable
    case notConfigured
    case cancelled
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "この端末ではFace IDを利用できません。端末の設定をご確認ください。"
        case .notConfigured:
            "Face IDログインが未設定です。パスワードでログインしてください。"
        case .cancelled:
            "Face ID認証が完了しませんでした。"
        case .invalidData:
            "Face IDログイン情報を読み取れませんでした。"
        }
    }
}

private struct KeychainBiometricCredentialStore: BiometricCredentialStore {
    private let service = "org.nagaoka.blog.k100.member.next.biometric"
    private let account = "firebase-refresh-token"
    private let availabilityKey = "biometricRefreshTokenStored"

    var hasCredential: Bool {
        UserDefaults.standard.bool(forKey: availabilityKey)
    }

    func save(_ refreshToken: String) throws {
        let context = LAContext()
        var authenticationError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &authenticationError
        ) else {
            throw BiometricCredentialError.unavailable
        }
        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &accessError
        ) else {
            throw BiometricCredentialError.unavailable
        }
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = Data(refreshToken.utf8)
        query[kSecAttrAccessControl as String] = access
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BiometricCredentialError.unavailable
        }
        UserDefaults.standard.set(true, forKey: availabilityKey)
    }

    func load() async throws -> String {
        guard hasCredential else {
            throw BiometricCredentialError.notConfigured
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                    kSecUseOperationPrompt as String: "Face IDでログインします"
                ]
                var result: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                guard status == errSecSuccess else {
                    continuation.resume(throwing: BiometricCredentialError.cancelled)
                    return
                }
                guard
                    let data = result as? Data,
                    let token = String(data: data, encoding: .utf8)
                else {
                    continuation.resume(throwing: BiometricCredentialError.invalidData)
                    return
                }
                continuation.resume(returning: token)
            }
        }
    }
}

private struct AccountFormView: View {
    @ObservedObject var model: AccountFeatureModel
    let isRegistration: Bool
    @State private var name = ""
    @State private var furigana = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isRegistration ? "会員登録" : "ログイン")
                .font(.title2.bold())
            if isRegistration {
                TextField("名前", text: $name)
                    .textContentType(.name)
                    .textFieldStyle(.roundedBorder)
                TextField("ふりがな", text: $furigana)
                    .textFieldStyle(.roundedBorder)
            }
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
                    model.register(
                        name: name,
                        furigana: furigana,
                        email: email,
                        password: password,
                        confirmation: confirmation
                    )
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
