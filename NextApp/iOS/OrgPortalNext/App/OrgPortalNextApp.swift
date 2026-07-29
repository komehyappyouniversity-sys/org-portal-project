import LocalAuthentication
import Security
import SwiftData
import SwiftUI
import VisionKit
import DataLayer
import DesignSystem
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
                FavoriteBookmarkRecord.self,
                FriendContactRecord.self,
                FriendInteractionHistoryRecord.self
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
    @StateObject private var appBackupModel: AppBackupFeatureModel
    @StateObject private var appSession: AppSession
    @StateObject private var accountModel: AccountFeatureModel
    @StateObject private var communityModel: CommunityFeatureModel
    @StateObject private var announcementModel: AnnouncementFeatureModel
    @StateObject private var postModel: PostFeatureModel

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
        let firebaseProjectID = Bundle.main.object(
            forInfoDictionaryKey: "FirebaseProjectID"
        ) as? String ?? ""
        let community = CommunityFeatureModel(
            repository: FirebaseRESTCommunityRepository(projectId: firebaseProjectID),
            session: session
        )
        _communityModel = StateObject(wrappedValue: community)
        _announcementModel = StateObject(
            wrappedValue: AnnouncementFeatureModel(
                repository: FirebaseRESTAnnouncementRepository(projectId: firebaseProjectID),
                session: session,
                memberships: { community.items.map(\.0) }
            )
        )
        _postModel = StateObject(
            wrappedValue: PostFeatureModel(
                repository: FirebaseRESTPostRepository(projectId: firebaseProjectID),
                session: session,
                memberships: { community.items.map(\.0) }
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
        let meetingMinutesRepository = SwiftDataMeetingMinutesRepository(
            modelContainer: modelContainer
        )
        _meetingMinutesModel = StateObject(
            wrappedValue: MeetingMinutesFeatureModel(
                repository: meetingMinutesRepository,
                recordingStore: meetingRecordingStore
            )
        )
        let snsCustomLinkRepository = SwiftDataSnsCustomLinkRepository(
            modelContainer: modelContainer
        )
        _snsPostingAssistantModel = StateObject(
            wrappedValue: SnsPostingAssistantFeatureModel(
                repository: snsCustomLinkRepository
            )
        )
        let favoriteBookmarkRepository = SwiftDataFavoriteBookmarkRepository(
            modelContainer: modelContainer
        )
        _favoriteBookmarkModel = StateObject(
            wrappedValue: FavoriteBookmarkFeatureModel(
                repository: favoriteBookmarkRepository
            )
        )
        _appBackupModel = StateObject(
            wrappedValue: AppBackupFeatureModel(
                service: AppBackupService(
                    scheduleRepository: scheduleRepository,
                    diaryRepository: diaryRepository,
                    photoStore: photoStore,
                    cashDistributionRepository: cashDistributionRepository,
                    meetingMinutesRepository: meetingMinutesRepository,
                    recordingStore: meetingRecordingStore,
                    snsCustomLinkRepository: snsCustomLinkRepository,
                    favoriteBookmarkRepository: favoriteBookmarkRepository
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
                favoriteBookmarkModel: favoriteBookmarkModel,
                appBackupModel: appBackupModel
            ),
            tools: ToolsHubView(
                scheduleModel: scheduleModel,
                diaryModel: diaryModel,
                cashDistributionModel: cashDistributionModel,
                meetingMinutesModel: meetingMinutesModel,
                snsPostingAssistantModel: snsPostingAssistantModel,
                favoriteBookmarkModel: favoriteBookmarkModel
            ),
            community: ConnectedRootView(
                communityModel: communityModel,
                postModel: postModel,
                announcementModel: announcementModel
            ),
            profile: AccountRootView(model: accountModel)
        )
    }
}

@MainActor
private final class CommunityFeatureModel: ObservableObject {
    @Published var code = ""
    @Published var publicQuery = ""
    @Published private(set) var publicItems: [Community] = []
    @Published private(set) var candidate: Community?
    @Published private(set) var items: [(CommunityMembership, Community)] = []
    @Published private(set) var adminAccess: CommunityAdminAccess?
    @Published private(set) var pendingApplications: [CommunityMembership] = []
    @Published private(set) var reviewingUserId: String?
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

    func refreshPublicCommunities() {
        isLoading = true
        message = nil
        Task {
            do {
                publicItems = try await repository.publicCommunities(query: publicQuery)
                isLoading = false
            } catch {
                publicItems = []
                isLoading = false
                message = error.localizedDescription
            }
        }
    }

    func prepareApplication(for community: Community) {
        guard isLoggedIn else {
            message = "参加申請には、マイページから会員登録またはログインが必要です。"
            return
        }
        candidate = community
        code = community.code
        message = community.joinEnabled
            ? "参加先を確認し、下の「参加申請」を押してください。"
            : "このコミュニティは現在、参加申請を受け付けていません。"
    }

    func apply(to community: Community) {
        guard isLoggedIn else {
            message = "参加申請には、マイページから会員登録またはログインが必要です。"
            return
        }
        guard community.joinEnabled else {
            message = "このコミュニティは現在、参加申請を受け付けていません。"
            return
        }
        candidate = community
        code = community.code
        apply()
    }

    func membershipStatus(for communityId: String) -> CommunityMembershipStatus? {
        items.first { $0.1.id == communityId }?.0.status
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
            await refreshManagement()
            isLoading = false
        } catch {
            isLoading = false
            message = error.localizedDescription
        }
    }

    func selectCommunity(_ communityId: String) {
        session.selectCommunity(communityId)
        Task { await refreshManagement() }
    }

    func review(_ application: CommunityMembership, status: CommunityMembershipStatus) {
        guard status == .approved || status == .rejected,
              let communityId = session.selectedCommunityId,
              let reviewerUserId = session.authenticatedUserId,
              let token = session.authenticationToken else { return }
        reviewingUserId = application.userId
        message = nil
        Task {
            do {
                try await repository.reviewApplication(
                    communityId: communityId,
                    applicantUserId: application.userId,
                    reviewerUserId: reviewerUserId,
                    status: status,
                    idToken: token
                )
                message = status == .approved ? "参加申請を承認しました。" : "参加申請を却下しました。"
                await refreshManagement()
            } catch {
                message = error.localizedDescription
            }
            reviewingUserId = nil
        }
    }

    private func refreshManagement() async {
        guard let communityId = session.selectedCommunityId,
              let userId = session.authenticatedUserId,
              let token = session.authenticationToken else {
            adminAccess = nil
            pendingApplications = []
            return
        }
        do {
            let access = try await repository.adminAccess(
                communityId: communityId,
                userId: userId,
                idToken: token
            )
            adminAccess = access
            pendingApplications = access?.canReviewMembers == true
                ? try await repository.pendingApplications(
                    communityId: communityId,
                    idToken: token
                )
                : []
        } catch {
            adminAccess = nil
            pendingApplications = []
            message = error.localizedDescription
        }
    }
}

@MainActor
private final class AnnouncementFeatureModel: ObservableObject {
    @Published private(set) var announcements: [Announcement] = []
    @Published private(set) var readIDs: Set<String> = []
    @Published var selected: Announcement?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let repository: any AnnouncementRepository
    let session: AppSession
    private let memberships: () -> [CommunityMembership]

    init(
        repository: any AnnouncementRepository,
        session: AppSession,
        memberships: @escaping () -> [CommunityMembership]
    ) {
        self.repository = repository
        self.session = session
        self.memberships = memberships
    }

    func refresh() {
        let communityID = session.selectedCommunityId
        let userID = session.authenticatedUserId
        let token = session.authenticationToken
        let membership = memberships().first {
            $0.communityId == communityID && $0.status == .approved
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                announcements = try await repository.announcements(
                    communityId: communityID,
                    membership: membership,
                    userId: userID,
                    idToken: token
                )
                if let userID, let token {
                    readIDs = try await repository.readAnnouncementIDs(
                        userId: userID,
                        idToken: token
                    )
                } else {
                    readIDs = []
                }
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = "お知らせを読み込めませんでした。時間をおいて再度お試しください。"
            }
        }
    }

    func open(_ announcement: Announcement) {
        selected = announcement
        guard let userID = session.authenticatedUserId,
              let token = session.authenticationToken,
              !readIDs.contains(announcement.id) else { return }
        Task {
            do {
                try await repository.markRead(
                    userId: userID,
                    announcementId: announcement.id,
                    idToken: token
                )
                readIDs.insert(announcement.id)
            } catch {
                errorMessage = "既読状態を保存できませんでした。"
            }
        }
    }
}

private struct ConnectedRootView: View {
    @ObservedObject var communityModel: CommunityFeatureModel
    @ObservedObject var postModel: PostFeatureModel
    @ObservedObject var announcementModel: AnnouncementFeatureModel
    @State private var selection = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("つながる", selection: $selection) {
                Text("コミュニティ").tag(0)
                Text("投稿").tag(1)
                Text("お知らせ").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            if selection == 0 {
                CommunityRootView(model: communityModel)
            } else if selection == 1 {
                PostRootView(model: postModel)
            } else {
                AnnouncementRootView(model: announcementModel)
            }
        }
    }
}

private struct AnnouncementRootView: View {
    @ObservedObject var model: AnnouncementFeatureModel

    private var refreshIdentity: String {
        [
            model.session.selectedCommunityId ?? "public",
            model.session.authenticatedUserId ?? "guest",
            model.session.authenticationToken == nil ? "signed-out" : "signed-in"
        ].joined(separator: ":")
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    LoadingState()
                } else if let errorMessage = model.errorMessage {
                    ErrorState(message: errorMessage, retry: model.refresh)
                } else if model.announcements.isEmpty {
                    EmptyState("お知らせはありません", systemImage: "bell")
                } else {
                    List {
                        let unread = model.announcements.filter {
                            !model.readIDs.contains($0.id)
                        }
                        let read = model.announcements.filter {
                            model.readIDs.contains($0.id)
                        }
                        if !unread.isEmpty {
                            Section("未読 \(unread.count)件") {
                                ForEach(unread) { announcement in
                                    announcementRow(announcement, isRead: false)
                                }
                            }
                        }
                        if !read.isEmpty {
                            Section("既読") {
                                ForEach(read) { announcement in
                                    announcementRow(announcement, isRead: true)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("お知らせ")
            .toolbar {
                Button("更新", action: model.refresh)
            }
            .task(id: refreshIdentity) {
                model.refresh()
            }
            .sheet(item: $model.selected) { announcement in
                AnnouncementDetailView(announcement: announcement)
            }
        }
    }

    private func announcementRow(
        _ announcement: Announcement,
        isRead: Bool
    ) -> some View {
        Button {
            model.open(announcement)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isRead ? "envelope.open" : "envelope.badge")
                    .foregroundStyle(isRead ? Color.secondary : Color.green)
                VStack(alignment: .leading, spacing: 5) {
                    Text(announcement.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(announcement.body)
                        .lineLimit(2)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AnnouncementDetailView: View {
    let announcement: Announcement
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(announcement.title).font(.title2.bold())
                    if let createdAt = announcement.createdAt {
                        Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                    Text(announcement.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(
                        Array(announcement.attachments.enumerated()),
                        id: \.offset
                    ) { _, attachment in
                        Link(attachment.name, destination: attachment.url)
                            .buttonStyle(.bordered)
                    }
                    if let zoomURL = announcement.zoomURL {
                        Link("Zoomを開く", destination: zoomURL)
                            .buttonStyle(.bordered)
                    }
                    if let videoURL = announcement.videoURL {
                        Link("動画を開く", destination: videoURL)
                            .buttonStyle(.bordered)
                    }
                    ShareLink(
                        item: "\(announcement.title)\n\n\(announcement.body)",
                        subject: Text(announcement.title)
                    ) {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
            }
            .navigationTitle("お知らせ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

private struct CommunityRootView: View {
    @ObservedObject var model: CommunityFeatureModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.isLoading { ProgressView() }
                    if let message = model.message {
                        Text(message)
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    publicCommunitySection
                    if !model.isLoggedIn {
                        ContentUnavailableView(
                            "ログインが必要です",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text("マイページで会員登録またはログイン後に参加申請できます。")
                        )
                    } else {
                        membershipSection
                        if model.adminAccess?.canReviewMembers == true {
                            applicationReviewSection
                        }
                        joinSection
                    }
                }
                .padding(24)
            }
            .navigationTitle("つながる")
            .task {
                model.refreshPublicCommunities()
                await model.refresh()
            }
            .sheet(isPresented: $model.showsScanner) {
                CommunityQRScanner { model.receivedScan($0) }
            }
        }
    }

    private var publicCommunitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("コミュニティを探す").font(.title2.bold())
            Text("公開中のコミュニティを見て回れます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                TextField("名前・コード・紹介文で検索", text: $model.publicQuery)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { model.refreshPublicCommunities() }
                Button("検索") { model.refreshPublicCommunities() }
                    .buttonStyle(.bordered)
            }
            if model.publicItems.isEmpty && !model.isLoading {
                Text("公開中のコミュニティは見つかりませんでした。")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.publicItems) { community in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        if !community.description.isEmpty {
                            Text(community.description)
                        }
                        if let homepage = community.homepageURL {
                            Link("ホームページを見る", destination: homepage)
                        }
                        let membershipStatus = model.membershipStatus(for: community.id)
                        Text(publicStatusText(
                            membershipStatus: membershipStatus,
                            joinEnabled: community.joinEnabled
                        ))
                            .font(.footnote)
                            .foregroundStyle(publicStatusColor(membershipStatus))
                        if membershipStatus == .approved {
                            Button(
                                model.session.selectedCommunityId == community.id
                                    ? "選択中のコミュニティ"
                                    : "このコミュニティへ切替"
                            ) {
                                model.selectCommunity(community.id)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.session.selectedCommunityId == community.id)
                        } else if membershipStatus == nil {
                            Button("このコミュニティへ参加申請") {
                                model.apply(to: community)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!community.joinEnabled || model.isLoading)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack(spacing: 12) {
                        CommunityLogo(community: community)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(community.name).font(.headline)
                            Text("コード: \(community.code)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                            model.selectCommunity(community.id)
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

    private var applicationReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("参加申請の承認").font(.title2.bold())
            if model.pendingApplications.isEmpty {
                Text("承認待ちの申請はありません。").foregroundStyle(.secondary)
            }
            ForEach(model.pendingApplications, id: \.id) { application in
                VStack(alignment: .leading, spacing: 8) {
                    Text(application.applicantName ?? "申請者")
                        .font(.headline)
                    if let furigana = application.applicantFurigana {
                        Text(furigana).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(application.applicantEmail ?? "利用者ID: \(application.userId)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    HStack {
                        Button("承認") { model.review(application, status: .approved) }
                            .buttonStyle(.borderedProminent)
                        Button("却下", role: .destructive) {
                            model.review(application, status: .rejected)
                        }
                        .buttonStyle(.bordered)
                    }
                    .disabled(model.reviewingUserId != nil)
                    if model.reviewingUserId == application.userId {
                        ProgressView()
                    }
                }
                .padding()
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
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

    private func publicStatusText(
        membershipStatus: CommunityMembershipStatus?,
        joinEnabled: Bool
    ) -> String {
        if let membershipStatus {
            return statusText(membershipStatus)
        }
        return joinEnabled ? "参加申請受付中" : "現在は参加申請受付外"
    }

    private func publicStatusColor(
        _ membershipStatus: CommunityMembershipStatus?
    ) -> Color {
        membershipStatus.map(statusColor) ?? .secondary
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
