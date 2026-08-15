import LocalAuthentication
import AVFoundation
import MediaPlayer
import Security
import SwiftData
import SwiftUI
import WebKit
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
                FriendInteractionHistoryRecord.self,
                VideoRepeatSettingRecord.self,
                BudgetSettlementReportRecord.self,
                BudgetEntryRecord.self
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
    @StateObject private var friendExchangeModel: FriendExchangeFeatureModel
    @StateObject private var appBackupModel: AppBackupFeatureModel
    @StateObject private var appSession: AppSession
    @StateObject private var accountModel: AccountFeatureModel
    @StateObject private var communityModel: CommunityFeatureModel
    @StateObject private var distributedVideoModel: DistributedVideoFeatureModel
    @StateObject private var announcementModel: AnnouncementFeatureModel
    @StateObject private var postModel: PostFeatureModel
    @StateObject private var budgetSettlementModel: BudgetSettlementFeatureModel

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
        let communityRepository = FirebaseRESTCommunityRepository(projectId: firebaseProjectID)
        let community = CommunityFeatureModel(
            repository: communityRepository,
            session: session
        )
        _communityModel = StateObject(wrappedValue: community)
        _distributedVideoModel = StateObject(
            wrappedValue: DistributedVideoFeatureModel(
                repository: communityRepository,
                session: session,
                canViewMembersOnlyVideo: { communityId in
                    community.items.contains {
                        $0.0.status == .approved && $0.1.id == communityId
                    }
                },
                memoStore: FeatureTools.VimeoMemoStore(),
                questionStore: FeatureTools.VideoQuestionDraftStore(),
                repeatSettingRepository: SwiftDataVideoRepeatSettingRepository(
                    modelContainer: modelContainer
                ),
                guestUserIdProvider: KeychainGuestUserIdProvider()
            )
        )
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
        let friendExchangeRepository = SwiftDataFriendExchangeRepository(
            modelContainer: modelContainer
        )
        _favoriteBookmarkModel = StateObject(
            wrappedValue: FavoriteBookmarkFeatureModel(
                repository: favoriteBookmarkRepository
            )
        )

        _friendExchangeModel = StateObject(
            wrappedValue: FriendExchangeFeatureModel(
                repository: friendExchangeRepository
            )
        )
        let budgetReceiptStore = LocalBudgetReceiptStore()
        let budgetLocalRepository = SwiftDataBudgetSettlementRepository(
            modelContainer: modelContainer,
            deleteReceipt: { try budgetReceiptStore.delete(reference: $0) }
        )
        let budgetRemoteRepository = FirebaseRESTBudgetSettlementRepository(
            projectId: firebaseProjectID,
            storageBucket: "\(firebaseProjectID).firebasestorage.app"
        )
        let budgetMigrationService = BudgetSettlementMigrationService(
            localRepository: budgetLocalRepository,
            localReceiptStore: budgetReceiptStore,
            remoteRepository: budgetRemoteRepository,
            stateStore: UserDefaultsBudgetMigrationStateStore()
        )
        _budgetSettlementModel = StateObject(
            wrappedValue: BudgetSettlementFeatureModel(
                localRepository: budgetLocalRepository,
                localReceiptStore: budgetReceiptStore,
                remoteRepository: budgetRemoteRepository,
                migrationService: budgetMigrationService,
                session: session
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
                    favoriteBookmarkRepository: favoriteBookmarkRepository,
                    friendExchangeRepository: friendExchangeRepository
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
                favoriteBookmarkModel: favoriteBookmarkModel,
                friendExchangeModel: friendExchangeModel,
                distributedVideoModel: distributedVideoModel,
                budgetSettlementModel: budgetSettlementModel
            ),
            community: ConnectedRootView(
                communityModel: communityModel,
                postModel: postModel,
                announcementModel: announcementModel
            ),
            profile: AccountRootView(
                model: accountModel,
                communityModel: communityModel,
                postModel: postModel
            )
        )
        .task(id: "\(appSession.authenticatedUserId ?? ""):\(appSession.selectedCommunityId ?? "")") {
            await distributedVideoModel.load()
        }
    }
}

private struct VimeoVideoMemo: Codable, Identifiable, Equatable {
    let id: String
    var text: String
    let playbackSeconds: Double
    let createdAt: Date
    var updatedAt: Date
}

@MainActor
private struct VimeoMemoStore {
    private let defaults = UserDefaults.standard
    private let storageKey = "vimeo_video_memos"

    func entries(communityId: String, videoId: String) -> [VimeoVideoMemo] {
        let stored = values()[key(communityId: communityId, videoId: videoId)] ?? ""
        guard !stored.isEmpty else { return [] }
        if let data = stored.data(using: .utf8),
           let entries = try? JSONDecoder().decode([VimeoVideoMemo].self, from: data) {
            return entries.sorted { $0.createdAt > $1.createdAt }
        }
        return [VimeoVideoMemo(
            id: "legacy",
            text: stored,
            playbackSeconds: 0,
            createdAt: .distantPast,
            updatedAt: .distantPast
        )]
    }

    func serialized(_ entries: [VimeoVideoMemo]) -> String {
        guard !entries.isEmpty,
              let data = try? JSONEncoder().encode(entries),
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }

    func save(communityId: String, videoId: String, entries: [VimeoVideoMemo]) {
        var current = values()
        let memoKey = key(communityId: communityId, videoId: videoId)
        let serialized = serialized(entries)
        if serialized.isEmpty {
            current.removeValue(forKey: memoKey)
        } else {
            current[memoKey] = serialized
        }
        defaults.set(current, forKey: storageKey)
    }

    func saveAll(_ values: [String: String]) {
        defaults.set(values, forKey: storageKey)
    }

    private func values() -> [String: String] {
        defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }

    private func key(communityId: String, videoId: String) -> String {
        "\(communityId):\(videoId)"
    }
}

private struct VimeoPlayerCommand: Equatable {
    enum Action: Equatable {
        case play
        case pause
        case stop
        case seek(Double)
        case seekAndPlay(Double)
    }

    let action: Action
    let token = UUID()
}

@MainActor
private struct VimeoPlayerView: UIViewRepresentable {
    let videoId: String
    let command: VimeoPlayerCommand?
    let initialPlaybackSeconds: Double
    let onTimeChanged: (Double) -> Void
    let onDurationChanged: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTimeChanged: onTimeChanged, onDurationChanged: onDurationChanged)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.loadHTMLString(
            """
            <html><body style='margin:0;background:#000'>
            <iframe src='https://player.vimeo.com/video/\(videoId)#t=\(initialPlaybackSeconds)s'
              style='width:100%;height:100%;border:0' allow='autoplay; fullscreen'
              allowfullscreen></iframe>
            <script src='https://player.vimeo.com/api/player.js'></script>
            <script>
              const vimeoFrame = document.querySelector('iframe');
              const vimeoPlayer = new Vimeo.Player(vimeoFrame);
              window.vimeoPlaybackSeconds = 0;
              window.vimeoDurationSeconds = 0;
              const initialPlaybackSeconds = \(initialPlaybackSeconds);
              const updateDuration = () => {
                vimeoPlayer.getDuration().then((seconds) => {
                  window.vimeoDurationSeconds = seconds || 0;
                });
              };
              const restoreInitialPlaybackPosition = () => {
                if (initialPlaybackSeconds <= 0) { return Promise.resolve(0); }
                return vimeoPlayer.setCurrentTime(initialPlaybackSeconds).then((seconds) => {
                  window.vimeoPlaybackSeconds = seconds || initialPlaybackSeconds;
                  return window.vimeoPlaybackSeconds;
                });
              };
              vimeoPlayer.ready().then(() => {
                updateDuration();
                return restoreInitialPlaybackPosition();
              }).then(() => {
                if (initialPlaybackSeconds <= 0) {
                  return vimeoPlayer.getCurrentTime().then((seconds) => {
                    window.vimeoPlaybackSeconds = seconds || 0;
                  });
                }
              });
              vimeoPlayer.on('loaded', updateDuration);
              vimeoPlayer.on('durationchange', (data) => {
                window.vimeoDurationSeconds = data.duration || window.vimeoDurationSeconds;
              });
              vimeoPlayer.on('timeupdate', (data) => {
                window.vimeoPlaybackSeconds = data.seconds || 0;
                window.vimeoDurationSeconds = data.duration || window.vimeoDurationSeconds;
              });
              window.vimeoCurrentTime = () => window.vimeoPlaybackSeconds;
              window.vimeoDuration = () => window.vimeoDurationSeconds;
              window.vimeoPlay = () => vimeoPlayer.play();
              window.vimeoPause = () => vimeoPlayer.pause();
              window.vimeoStop = () => vimeoPlayer.pause().then(() => vimeoPlayer.setCurrentTime(0));
              window.vimeoSeek = (seconds) => vimeoPlayer.setCurrentTime(seconds);
              window.vimeoSeekAndPlay = (seconds) => vimeoPlayer.setCurrentTime(seconds).then(() => vimeoPlayer.play());
            </script></body></html>
            """,
            baseURL: URL(string: "https://player.vimeo.com")
        )
        context.coordinator.start(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.apply(command, to: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        private let onTimeChanged: (Double) -> Void
        private let onDurationChanged: (Double) -> Void
        private var timer: Timer?
        private var lastCommandToken: UUID?

        init(onTimeChanged: @escaping (Double) -> Void, onDurationChanged: @escaping (Double) -> Void) {
            self.onTimeChanged = onTimeChanged
            self.onDurationChanged = onDurationChanged
        }

        func start(_ webView: WKWebView) {
            refreshPlaybackState(in: webView)
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self, weak webView] _ in
                Task { @MainActor [weak self, weak webView] in
                    guard let self, let webView else { return }
                    self.refreshPlaybackState(in: webView)
                }
            }
        }

        private func refreshPlaybackState(in webView: WKWebView) {
            webView.evaluateJavaScript("window.vimeoCurrentTime ? window.vimeoCurrentTime() : 0") { [weak self] value, _ in
                if let seconds = value as? Double {
                    self?.onTimeChanged(seconds)
                }
            }
            webView.evaluateJavaScript("window.vimeoDuration ? window.vimeoDuration() : 0") { [weak self] value, _ in
                if let seconds = value as? Double, seconds > 0 {
                    self?.onDurationChanged(seconds)
                }
            }
        }

        func apply(_ command: VimeoPlayerCommand?, to webView: WKWebView) {
            guard let command, command.token != lastCommandToken else { return }
            lastCommandToken = command.token
            let script: String
            switch command.action {
            case .play: script = "window.vimeoPlay ? window.vimeoPlay() : null"
            case .pause: script = "window.vimeoPause ? window.vimeoPause() : null"
            case .stop: script = "window.vimeoStop ? window.vimeoStop() : null"
            case let .seek(seconds):
                script = "window.vimeoSeek ? window.vimeoSeek(\(seconds)) : null"
            case let .seekAndPlay(seconds):
                script = "window.vimeoSeekAndPlay ? window.vimeoSeekAndPlay(\(seconds)) : null"
            }
            webView.evaluateJavaScript(script)
        }

        func stop() {
            timer?.invalidate()
            timer = nil
        }
    }
}

private struct VimeoPlayerControlsView: View {
    enum Layout {
        case standard
        case sliderOnly
        case actionsOnly
    }

    let seekTo: (VimeoPlayerCommand) -> Void
    @Binding var playbackSeconds: Double
    let duration: Double
    let layout: Layout

    @State private var isScrubbing = false
    @State private var scrubSeconds = 0.0

    var body: some View {
        switch layout {
        case .standard:
            VStack(alignment: .leading, spacing: 8) {
                playbackSlider
                HStack(spacing: 8) { playbackActions }
            }
        case .sliderOnly:
            playbackSlider
        case .actionsOnly:
            VStack(spacing: 6) { playbackActions }
        }
    }

    private var playbackSlider: some View {
        HStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubSeconds : playbackSeconds },
                    set: { scrubSeconds = $0 }
                ),
                in: 0...(duration > 0 ? duration : 1),
                onEditingChanged: { editing in
                    if editing {
                        scrubSeconds = playbackSeconds
                        isScrubbing = true
                    } else {
                        let target = scrubSeconds
                        isScrubbing = false
                        playbackSeconds = target
                        seekTo(VimeoPlayerCommand(action: .seek(target)))
                    }
                }
            )
            .accessibilityElement(children: .combine)

            Text("\(formatPlayback(isScrubbing ? scrubSeconds : playbackSeconds)) / \(formatPlayback(duration))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 95, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var playbackActions: some View {
        Button {
            seekTo(VimeoPlayerCommand(action: .play))
        } label: {
            Label("再生", systemImage: "play.fill")
        }
        .buttonStyle(.borderedProminent)
        .labelStyle(.iconOnly)
        .frame(height: 44)

        Button {
            seekTo(VimeoPlayerCommand(action: .pause))
        } label: {
            Label("一時停止", systemImage: "pause.fill")
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .frame(height: 44)

        Button {
            seekTo(VimeoPlayerCommand(action: .stop))
        } label: {
            Label("停止", systemImage: "stop.fill")
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .frame(height: 44)

        Button("-1秒") {
            seek(by: -1)
        }
        .buttonStyle(.bordered)
        .frame(height: 44)

        Button("+1秒") {
            seek(by: 1)
        }
        .buttonStyle(.bordered)
        .frame(height: 44)
    }

    private func seek(by seconds: Double) {
        let next: Double
        if duration > 0 {
            next = min(max(playbackSeconds + seconds, 0), duration)
        } else {
            next = max(playbackSeconds + seconds, 0)
        }
        playbackSeconds = next
        seekTo(VimeoPlayerCommand(action: .seek(next)))
    }

    private func formatPlayback(_ seconds: Double) -> String {
        let clamped = max(0, Int(seconds.rounded()))
        return "\(clamped / 60):\(String(format: "%02d", clamped % 60))"
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
    @Published private(set) var administrators: [CommunityAdmin] = []
    @Published private(set) var communityMembers: [CommunityMembership] = []
    @Published private(set) var distributedVideos: [DistributedVideo] = []
    @Published private(set) var bookingEvents: [BookingEvent] = []
    @Published private(set) var selectedBookingEventID: String?
    @Published private(set) var bookingSlots: [BookingSlot] = []
    @Published private(set) var bookedSlotIDs: Set<String> = []
    @Published private(set) var myBookingReservations: [BookingReservation] = []
    @Published private(set) var myBookingSlots: [String: BookingSlot] = [:]
    @Published private(set) var bookingProcessingSlotID: String?
    @Published private(set) var managedVideos: [DistributedVideo] = []
    @Published private(set) var managedBookingEvents: [BookingEvent] = []
    @Published private(set) var selectedManagedBookingEventID: String?
    @Published private(set) var managedBookingSlots: [BookingSlot] = []
    @Published private(set) var managedBookingReservations: [BookingReservation] = []
    @Published private(set) var vimeoLibraryVideos: [DistributedVideo] = []
    @Published private(set) var vimeoFolders: [VimeoFolder] = []
    @Published private(set) var vimeoConfiguration = VimeoConfiguration()
    @Published private(set) var videoQuestions: [VideoQuestion] = []
    @Published private(set) var adminVideoQuestions: [VideoQuestion] = []
    @Published private(set) var auditLogs: [CommunityAuditLog] = []
    @Published private(set) var radioPrograms: [RadioProgram] = []
    @Published private(set) var radioPlaybackRecords: [RadioPlaybackRecord] = []
    @Published private(set) var radioPlayingProgramID: String?
    @Published private(set) var radioIsPlaying = false
    @Published private(set) var radioIsLoading = false
    private let memoStore: VimeoMemoStore
    @Published private(set) var reviewingUserId: String?
    @Published private(set) var isLoading = false
    @Published var message: String?
    @Published var showsScanner = false

    private let repository: any CommunityRepository
    let session: AppSession
    private var radioPlayer: AVPlayer?
    private var radioPlaybackEndObserver: NSObjectProtocol?
    private var radioPeriodicTimeObserver: Any?
    private var radioSessionObservers: [NSObjectProtocol] = []
    private var radioSaveTask: Task<Void, Never>?
    private var radioWasPlayingBeforeInterruption = false
    private var membershipsUserID: String?

    init(
        repository: any CommunityRepository,
        session: AppSession,
        memoStore: VimeoMemoStore = VimeoMemoStore()
    ) {
        self.repository = repository
        self.session = session
        self.memoStore = memoStore
        configureRadioRemoteCommands()
        observeRadioAudioSession()
    }

    func memos(for video: DistributedVideo) -> [VimeoVideoMemo] {
        memoStore.entries(communityId: video.communityId, videoId: video.id)
    }

    func addMemo(_ text: String, for video: DistributedVideo, playbackSeconds: Double) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            message = "メモを入力してください。"
            return
        }
        var entries = memos(for: video)
        entries.append(VimeoVideoMemo(
            id: UUID().uuidString,
            text: normalized,
            playbackSeconds: playbackSeconds,
            createdAt: Date(),
            updatedAt: Date()
        ))
        persistMemos(entries, for: video, successMessage: "動画メモを追加しました。")
    }

    func updateMemo(_ entry: VimeoVideoMemo, text: String, for video: DistributedVideo) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            message = "メモを入力してください。"
            return
        }
        let entries = memos(for: video).map { item in
            item.id == entry.id
                ? VimeoVideoMemo(
                    id: item.id,
                    text: normalized,
                    playbackSeconds: item.playbackSeconds,
                    createdAt: item.createdAt,
                    updatedAt: Date()
                )
                : item
        }
        persistMemos(entries, for: video, successMessage: "動画メモを更新しました。")
    }

    func deleteMemo(_ entry: VimeoVideoMemo, for video: DistributedVideo) {
        let entries = memos(for: video).filter { $0.id != entry.id }
        persistMemos(entries, for: video, successMessage: "動画メモを削除しました。")
    }

    private func persistMemos(
        _ entries: [VimeoVideoMemo],
        for video: DistributedVideo,
        successMessage: String
    ) {
        guard let userId = session.authenticatedUserId,
              let token = session.authenticationToken else { return }
        let payload = memoStore.serialized(entries)
        Task {
            do {
                try await repository.saveVideoMemo(
                    userId: userId,
                    communityId: video.communityId,
                    videoId: video.id,
                    memo: payload,
                    idToken: token
                )
                memoStore.save(communityId: video.communityId, videoId: video.id, entries: entries)
                message = successMessage
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func questions(for video: DistributedVideo) -> [VideoQuestion] {
        videoQuestions.filter { $0.videoId == video.id }
    }

    func submitVideoQuestion(
        _ question: String,
        memo: String,
        for video: DistributedVideo,
        playbackSeconds: Double
    ) {
        guard let userId = session.authenticatedUserId,
              let token = session.authenticationToken,
              let communityId = session.selectedCommunityId else { return }
        Task {
            do {
                try await repository.saveVideoQuestion(
                    communityId: communityId,
                    memberUid: userId,
                    video: video,
                    memoText: memo,
                    questionText: question,
                    playbackSeconds: playbackSeconds,
                    clientRequestId: UUID().uuidString.lowercased(),
                    idToken: token
                )
                message = "質問を送信しました。"
                await refreshManagement()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func answerVideoQuestion(_ questionID: String, answer: String) {
        guard canReviewMembers,
              let communityId = session.selectedCommunityId,
              let token = session.authenticationToken else { return }
        Task {
            do {
                try await repository.answerVideoQuestion(
                    communityId: communityId,
                    questionId: questionID,
                    answerText: answer,
                    idToken: token
                )
                message = "回答を保存しました。"
                await refreshManagement()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    var isLoggedIn: Bool {
        session.authenticatedUserId != nil && session.authenticationToken != nil
    }

    var canReviewMembers: Bool {
        adminAccess?.canReviewMembers == true
    }

    var isOwner: Bool {
        adminAccess?.role == "owner"
    }

    var canAccessRadio: Bool {
        guard isLoggedIn,
              membershipsUserID == session.authenticatedUserId,
              let communityId = session.selectedCommunityId else { return false }
        return items.contains {
            $0.0.status == .approved && $0.1.id == communityId
        }
    }

    var administratorCandidates: [CommunityMembership] {
        let activeAdminIDs = Set(
            administrators.filter(\.isActive).map(\.userId)
        )
        let query = adminQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return communityMembers
            .filter { member in
                guard member.status == .approved,
                      !activeAdminIDs.contains(member.userId) else { return false }
                guard !query.isEmpty else { return true }
                return [
                    member.userId,
                    member.applicantName,
                    member.applicantFurigana,
                    member.applicantEmail
                ].compactMap { $0 }.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
            }
            .sorted { ($0.applicantName ?? $0.userId) < ($1.applicantName ?? $1.userId) }
    }

    @Published var adminQuery = ""

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
        if membershipStatus(for: community.id) != nil {
            message = "このコミュニティには既に参加申請済みです。状態を確認してください。"
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
            membershipsUserID = nil
            items = []
            clearRadioState()
            return
        }
        if membershipsUserID != userId {
            membershipsUserID = nil
            items = []
            clearRadioState()
        }
        isLoading = true
        do {
            items = try await repository.memberships(userId: userId, idToken: token)
            membershipsUserID = userId
            let approved = items.filter { $0.0.status == .approved }
            if session.selectedCommunityId == nil, let first = approved.first {
                session.selectCommunity(first.1.id)
            }
            session.updateUserStage(approved.isEmpty ? .guest : .member)
            await refreshManagement()
            await refreshBookingEvents()
            await refreshRadioPrograms()
            isLoading = false
        } catch {
            isLoading = false
            message = error.localizedDescription
        }
    }

    func selectCommunity(_ communityId: String) {
        session.selectCommunity(communityId)
        Task {
            await refreshManagement()
            await refreshRadioPrograms()
        }
    }

    func refreshRadioPrograms() async {
        guard canAccessRadio,
              let communityId = session.selectedCommunityId,
              let userId = session.authenticatedUserId,
              let token = session.authenticationToken else {
            clearRadioState()
            return
        }
        radioIsLoading = true
        do {
            async let programsRequest = repository.radioPrograms(
                communityId: communityId,
                idToken: token
            )
            async let recordsRequest = repository.radioPlaybackRecords(
                userId: userId,
                idToken: token
            )
            let (programs, records) = try await (programsRequest, recordsRequest)
            guard session.selectedCommunityId == communityId, canAccessRadio else { return }
            if let playingID = radioPlayingProgramID,
               !programs.contains(where: { $0.id == playingID }) {
                stopRadioPlayback()
            }
            radioPrograms = programs
            var refreshedRecords = records
            if let playingID = radioPlayingProgramID,
               let activeRecord = playbackRecord(for: playingID) {
                if let index = refreshedRecords.firstIndex(where: {
                    $0.userId == userId && $0.programId == playingID
                }) {
                    refreshedRecords[index] = activeRecord
                } else {
                    refreshedRecords.append(activeRecord)
                }
            }
            radioPlaybackRecords = refreshedRecords
            radioIsLoading = false
        } catch {
            guard session.selectedCommunityId == communityId else { return }
            radioPrograms = []
            radioIsLoading = false
            message = error.localizedDescription
        }
    }

    func isRadioPlayable(_ program: RadioProgram) -> Bool {
        RadioPlaybackPolicy.isPlayable(program, at: Date())
    }

    func toggleRadioPlayback(_ program: RadioProgram) {
        guard isRadioPlayable(program) else {
            message = "この番組は配信開始前です。"
            return
        }
        if radioPlayingProgramID == program.id {
            radioIsPlaying ? pauseRadioPlayback() : resumeRadioPlayback()
            return
        }

        stopRadioPlayback()
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            let player = AVPlayer(url: program.audioUrl)
            let resumePosition = playbackRecord(for: program.id)?.lastPositionSeconds ?? 0
            radioPlayer = player
            radioPlayingProgramID = program.id
            radioIsPlaying = true
            message = nil
            radioPlaybackEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.finishRadioPlayback() }
            }
            radioPeriodicTimeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 30, preferredTimescale: 1),
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.persistRadioPosition() }
            }
            if resumePosition > 0 {
                player.seek(to: CMTime(seconds: resumePosition, preferredTimescale: 600))
            }
            player.play()
            recordRadioPlayback(program.id)
            updateNowPlayingInfo(program: program)
        } catch {
            stopRadioPlayback()
            message = "再生できませんでした。ネットワーク接続と音声URLをご確認ください。"
        }
    }

    func playbackRecord(for programID: String) -> RadioPlaybackRecord? {
        guard let userID = session.authenticatedUserId else { return nil }
        return radioPlaybackRecords.first {
            $0.userId == userID && $0.programId == programID
        }
    }

    private func recordRadioPlayback(_ programID: String) {
        guard let userID = session.authenticatedUserId else { return }
        let now = Date()
        let index = radioPlaybackRecords.firstIndex(where: {
            $0.userId == userID && $0.programId == programID
        })
        let record = RadioPlaybackRecordPolicy.started(
            existing: index.map { radioPlaybackRecords[$0] },
            userId: userID,
            programId: programID,
            at: now
        )
        if let index {
            radioPlaybackRecords[index] = record
        } else {
            radioPlaybackRecords.append(record)
        }
        saveRadioPlaybackRecord(record)
    }

    func stopRadioPlayback() {
        persistRadioPosition()
        radioPlayer?.pause()
        if let timeObserver = radioPeriodicTimeObserver, let player = radioPlayer {
            player.removeTimeObserver(timeObserver)
        }
        radioPeriodicTimeObserver = nil
        radioPlayer = nil
        radioPlayingProgramID = nil
        radioIsPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        if let observer = radioPlaybackEndObserver {
            NotificationCenter.default.removeObserver(observer)
            radioPlaybackEndObserver = nil
        }
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func pauseRadioPlayback() {
        guard radioPlayingProgramID != nil else { return }
        radioPlayer?.pause()
        radioIsPlaying = false
        persistRadioPosition()
        updateNowPlayingInfo()
    }

    private func resumeRadioPlayback() {
        guard radioPlayer != nil else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            radioPlayer?.play()
            radioIsPlaying = true
            updateNowPlayingInfo()
        } catch {
            message = "再生を再開できませんでした。"
        }
    }

    private func finishRadioPlayback() {
        persistRadioPosition(positionOverride: 0)
        stopRadioPlaybackWithoutSaving()
    }

    private func stopRadioPlaybackWithoutSaving() {
        radioPlayer?.pause()
        if let timeObserver = radioPeriodicTimeObserver, let player = radioPlayer {
            player.removeTimeObserver(timeObserver)
        }
        radioPeriodicTimeObserver = nil
        radioPlayer = nil
        radioPlayingProgramID = nil
        radioIsPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        if let observer = radioPlaybackEndObserver {
            NotificationCenter.default.removeObserver(observer)
            radioPlaybackEndObserver = nil
        }
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func persistRadioPosition(positionOverride: Double? = nil) {
        guard let programID = radioPlayingProgramID,
              let userID = session.authenticatedUserId,
              let index = radioPlaybackRecords.firstIndex(where: {
                  $0.userId == userID && $0.programId == programID
              }) else { return }
        let rawPosition = positionOverride ?? radioPlayer?.currentTime().seconds ?? 0
        let record = RadioPlaybackRecordPolicy.updatingPosition(
            radioPlaybackRecords[index],
            positionSeconds: rawPosition,
            at: Date()
        )
        radioPlaybackRecords[index] = record
        saveRadioPlaybackRecord(record)
        updateNowPlayingInfo()
    }

    private func saveRadioPlaybackRecord(_ record: RadioPlaybackRecord) {
        guard let token = session.authenticationToken else { return }
        let previousTask = radioSaveTask
        radioSaveTask = Task {
            _ = await previousTask?.result
            try? await repository.saveRadioPlaybackRecord(record, idToken: token)
        }
    }

    private func configureRadioRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.stopCommand.isEnabled = true
        commands.togglePlayPauseCommand.isEnabled = true
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resumeRadioPlayback() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pauseRadioPlayback() }
            return .success
        }
        commands.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stopRadioPlayback() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.radioIsPlaying ? self.pauseRadioPlayback() : self.resumeRadioPlayback()
            }
            return .success
        }
    }

    private func observeRadioAudioSession() {
        let center = NotificationCenter.default
        radioSessionObservers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                self?.handleRadioInterruption(rawType: rawType, rawOptions: rawOptions)
            }
        })
        radioSessionObservers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in self?.handleRadioRouteChange(rawReason: rawReason) }
        })
    }

    private func handleRadioInterruption(rawType: UInt?, rawOptions: UInt?) {
        guard let rawType,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            radioWasPlayingBeforeInterruption = radioIsPlaying
            if radioIsPlaying { pauseRadioPlayback() }
        case .ended:
            let systemAllowsResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions ?? 0)
                .contains(.shouldResume)
            if RadioPlaybackInterruptionPolicy.shouldResume(
                wasPlayingBeforeInterruption: radioWasPlayingBeforeInterruption,
                systemAllowsResume: systemAllowsResume
            ) {
                resumeRadioPlayback()
            }
            radioWasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRadioRouteChange(rawReason: UInt?) {
        guard let rawReason,
              AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable else {
            return
        }
        radioWasPlayingBeforeInterruption = false
        if radioIsPlaying { pauseRadioPlayback() }
    }

    private func updateNowPlayingInfo(program: RadioProgram? = nil) {
        let resolvedProgram = program ?? radioPlayingProgramID.flatMap { id in
            radioPrograms.first { $0.id == id }
        }
        guard let resolvedProgram else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: resolvedProgram.title,
            MPMediaItemPropertyArtist: "インターネットラジオ",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(
                0,
                radioPlayer?.currentTime().seconds.isFinite == true
                    ? radioPlayer?.currentTime().seconds ?? 0
                    : 0
            ),
            MPNowPlayingInfoPropertyPlaybackRate: radioIsPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let duration = radioPlayer?.currentItem?.duration.seconds, duration.isFinite {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func clearRadioState() {
        stopRadioPlayback()
        radioPrograms = []
        radioPlaybackRecords = []
        radioIsLoading = false
    }

    func review(
        _ application: CommunityMembership,
        status: CommunityMembershipStatus,
        auditAction: String? = nil,
        successMessage: String? = nil
    ) {
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
                    auditAction: auditAction,
                    idToken: token
                )
                message = successMessage
                    ?? (status == .approved ? "参加申請を承認しました。" : "参加申請を却下しました。")
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
            administrators = []
            communityMembers = []
            distributedVideos = []
            managedVideos = []
            managedBookingEvents = []
            selectedManagedBookingEventID = nil
            managedBookingSlots = []
            managedBookingReservations = []
            vimeoLibraryVideos = []
            vimeoConfiguration = VimeoConfiguration()
            adminVideoQuestions = []
            auditLogs = []
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
            administrators = access?.canReviewMembers == true
                ? try await repository.administrators(
                    communityId: communityId,
                    idToken: token
                )
                : []
            communityMembers = access?.canReviewMembers == true
                ? try await repository.communityMembers(
                    communityId: communityId,
                    idToken: token
                )
                : []
            managedVideos = access?.canReviewMembers == true
                ? try await repository.adminCommunityVideos(
                    communityId: communityId,
                    idToken: token
                )
                : []
            managedBookingEvents = access?.canReviewMembers == true
                ? (try? await repository.adminBookingEvents(
                    communityId: communityId,
                    idToken: token
                )) ?? []
                : []
            vimeoLibraryVideos = []
            vimeoConfiguration = access?.canReviewMembers == true
                ? (try? await repository.vimeoConfiguration(
                    communityId: communityId,
                    idToken: token
                )) ?? VimeoConfiguration()
                : VimeoConfiguration()
            distributedVideos = try await repository.communityVideos(
                communityId: communityId,
                idToken: token
            )
            adminVideoQuestions = access?.canReviewMembers == true
                ? (try? await repository.adminVideoQuestions(
                    communityId: communityId,
                    idToken: token
                )) ?? []
                : []
            auditLogs = access?.canReviewMembers == true
                ? (try? await repository.auditLogs(communityId: communityId, idToken: token)) ?? []
                : []
            if let remoteMemos = try? await repository.videoMemos(
                userId: userId,
                idToken: token
            ) {
                memoStore.saveAll(remoteMemos)
            }
            videoQuestions = (try? await repository.videoQuestions(
                communityId: communityId,
                memberUid: userId,
                idToken: token
            )) ?? []
        } catch {
            adminAccess = nil
            pendingApplications = []
            administrators = []
            communityMembers = []
            distributedVideos = []
            managedVideos = []
            managedBookingEvents = []
            selectedManagedBookingEventID = nil
            managedBookingSlots = []
            managedBookingReservations = []
            vimeoLibraryVideos = []
            vimeoConfiguration = VimeoConfiguration()
            adminVideoQuestions = []
            auditLogs = []
            message = error.localizedDescription
        }
    }

    func refreshBookingStatus() {
        Task {
            await refreshBookingEvents()
            if let eventID = selectedManagedBookingEventID {
                await selectManagedBookingEvent(eventID)
            }
        }
    }

    private func refreshBookingEvents() async {
        guard let communityID = session.selectedCommunityId,
              let token = session.authenticationToken else {
            bookingEvents = []
            selectedBookingEventID = nil
            bookingSlots = []
            bookedSlotIDs = []
            myBookingReservations = []
            myBookingSlots = [:]
            bookingProcessingSlotID = nil
            return
        }
        do {
            bookingEvents = try await repository.bookingEvents(communityId: communityID, idToken: token)
            let reservations = (try? await repository.myBookingReservations(
                communityId: communityID,
                userId: session.authenticatedUserId ?? "",
                idToken: token
            )) ?? []
            myBookingReservations = reservations
            var slotsByID: [String: BookingSlot] = [:]
            for eventID in Set(reservations.map(\.eventId)) {
                let slots = (try? await repository.bookingSlots(
                    communityId: communityID,
                    eventId: eventID,
                    idToken: token
                )) ?? []
                for slot in slots {
                    slotsByID["\(eventID):\(slot.id)"] = slot
                }
            }
            myBookingSlots = slotsByID
            if let selectedBookingEventID,
               bookingEvents.contains(where: { $0.id == selectedBookingEventID }) {
                await refreshBookingDetails(eventID: selectedBookingEventID)
            } else {
                selectedBookingEventID = nil
                bookingSlots = []
                bookedSlotIDs = []
            }
        } catch {
            bookingEvents = []
        }
    }

    func selectBookingEvent(_ eventID: String) async {
        selectedBookingEventID = eventID
        bookingSlots = []
        bookedSlotIDs = []
        await refreshBookingDetails(eventID: eventID)
    }

    func reserveBooking(event: BookingEvent, slot: BookingSlot) async {
        await updateBooking(event: event, slot: slot, reserve: true)
    }

    func cancelBooking(event: BookingEvent, slot: BookingSlot) async {
        await updateBooking(event: event, slot: slot, reserve: false)
    }

    private func refreshBookingDetails(eventID: String) async {
        guard let communityID = session.selectedCommunityId,
              let userID = session.authenticatedUserId,
              let token = session.authenticationToken else { return }
        do {
            async let slots = repository.bookingSlots(
                communityId: communityID,
                eventId: eventID,
                idToken: token
            )
            async let booked = repository.bookedSlotIDs(
                communityId: communityID,
                eventId: eventID,
                userId: userID,
                idToken: token
            )
            let (loadedSlots, loadedBooked) = try await (slots, booked)
            guard selectedBookingEventID == eventID else { return }
            bookingSlots = loadedSlots
            bookedSlotIDs = loadedBooked
        } catch {
            bookingSlots = []
            bookedSlotIDs = []
        }
    }

    private func updateBooking(event: BookingEvent, slot: BookingSlot, reserve: Bool) async {
        guard let communityID = session.selectedCommunityId,
              let token = session.authenticationToken else { return }
        bookingProcessingSlotID = slot.id
        message = nil
        do {
            if reserve {
                try await repository.reserveBookingSlot(
                    communityId: communityID,
                    eventId: event.id,
                    slotId: slot.id,
                    idToken: token
                )
                message = "イベントを予約しました。"
            } else {
                try await repository.cancelBookingSlot(
                    communityId: communityID,
                    eventId: event.id,
                    slotId: slot.id,
                    idToken: token
                )
                message = "イベント予約をキャンセルしました。"
            }
            await refreshBookingDetails(eventID: event.id)
        } catch {
            message = "イベント予約を更新できませんでした: \(error.localizedDescription)"
        }
        bookingProcessingSlotID = nil
    }

    func saveVimeoConfiguration(accessToken: String, userId: String, query: String) {
        guard let communityId = session.selectedCommunityId,
              let token = session.authenticationToken,
              !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = "VimeoアクセストークンとユーザーIDを入力してください。"
            return
        }
        Task {
            do {
                try await repository.saveVimeoConfiguration(
                    communityId: communityId,
                    accessToken: accessToken,
                    userId: userId,
                    query: query,
                    idToken: token
                )
                message = "Vimeo接続設定を保存しました。"
                await refreshManagement()
            } catch {
                message = "Vimeo接続設定の保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func refreshVimeoLibrary() {
        guard let communityId = session.selectedCommunityId,
              let token = session.authenticationToken,
              adminAccess?.canReviewMembers == true else { return }
        Task {
            do {
                vimeoLibraryVideos = try await repository.vimeoLibraryVideos(
                    communityId: communityId,
                    idToken: token
                )
                message = "Vimeoから\(vimeoLibraryVideos.count)件の動画を取得しました。"
            } catch {
                vimeoLibraryVideos = []
                message = "Vimeo動画の取得に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func clearVimeoLibrary() {
        vimeoLibraryVideos = []
    }

    func saveBookingEvent(
        eventID: String,
        title: String,
        description: String,
        eventDate: Date?,
        feeAmount: Int,
        paymentRequired: Bool,
        zoomURL: String,
        isPublished: Bool
    ) {
        guard let communityID = session.selectedCommunityId,
              let token = session.authenticationToken,
              adminAccess?.canReviewMembers == true else { return }
        Task {
            do {
                try await repository.saveBookingEvent(
                    communityId: communityID,
                    eventId: eventID,
                    title: title,
                    description: description,
                    eventDate: eventDate,
                    feeAmount: feeAmount,
                    paymentRequired: paymentRequired,
                    zoomURL: zoomURL,
                    isPublished: isPublished,
                    idToken: token
                )
                message = "イベントを保存しました。"
                await refreshManagement()
                await refreshBookingEvents()
            } catch {
                message = "イベントを保存できませんでした: \(error.localizedDescription)"
            }
        }
    }

    func saveBookingSlot(
        eventID: String,
        slotID: String,
        startAt: Date?,
        endAt: Date?,
        capacity: Int,
        isOpen: Bool
    ) {
        guard let communityID = session.selectedCommunityId,
              let token = session.authenticationToken,
              adminAccess?.canReviewMembers == true else { return }
        Task {
            do {
                try await repository.saveBookingSlot(
                    communityId: communityID,
                    eventId: eventID,
                    slotId: slotID,
                    startAt: startAt,
                    endAt: endAt,
                    capacity: capacity,
                    isOpen: isOpen,
                    idToken: token
                )
                message = "予約枠を保存しました。"
                await refreshBookingDetails(eventID: eventID)
            } catch {
                message = "予約枠を保存できませんでした: \(error.localizedDescription)"
            }
        }
    }

    func selectManagedBookingEvent(_ eventID: String) async {
        guard let communityID = session.selectedCommunityId,
              let token = session.authenticationToken,
              adminAccess?.canReviewMembers == true else { return }
        selectedManagedBookingEventID = eventID
        managedBookingSlots = []
        managedBookingReservations = []
        do {
            async let slots = repository.bookingSlots(
                communityId: communityID,
                eventId: eventID,
                idToken: token
            )
            async let reservations = repository.bookingReservations(
                communityId: communityID,
                eventId: eventID,
                idToken: token
            )
            let (loadedSlots, loadedReservations) = try await (slots, reservations)
            guard selectedManagedBookingEventID == eventID else { return }
            managedBookingSlots = loadedSlots
            managedBookingReservations = loadedReservations
        } catch {
            message = "予約状況を取得できませんでした: \(error.localizedDescription)"
        }
    }

    func saveCommunityVideos(_ videos: [DistributedVideo], isPublished: Bool) {
        guard let communityId = session.selectedCommunityId,
              let token = session.authenticationToken,
              !videos.isEmpty else { return }
        Task {
            do {
                for video in videos {
                    try await repository.saveCommunityVideo(
                        communityId: communityId,
                        videoId: video.vimeoVideoId,
                        title: video.title,
                        description: video.description,
                        vimeoVideoId: video.vimeoVideoId,
                        vimeoURL: video.videoURL?.absoluteString ?? "",
                        thumbnailURL: video.thumbnailURL?.absoluteString ?? "",
                        isPublished: isPublished,
                        idToken: token
                    )
                }
                message = "\(videos.count)件の動画を\(isPublished ? "公開" : "下書き保存")しました。"
                await refreshManagement()
            } catch {
                message = "動画の一括保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func refreshVimeoFolders() {
        guard let communityId = session.selectedCommunityId,
              let token = session.authenticationToken,
              adminAccess?.canReviewMembers == true else { return }
        Task {
            do {
                vimeoFolders = try await repository.vimeoFolders(communityId: communityId, idToken: token)
                message = "Vimeoから\(vimeoFolders.count)件のフォルダを取得しました。"
            } catch {
                vimeoFolders = []
                message = "Vimeoフォルダの取得に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func refreshVimeoFolderVideos(folder: VimeoFolder) {
        guard let communityId = session.selectedCommunityId,
              let token = session.authenticationToken,
              adminAccess?.canReviewMembers == true else { return }
        Task {
            do {
                vimeoLibraryVideos = try await repository.vimeoFolderVideos(
                    communityId: communityId,
                    folderId: folder.id,
                    idToken: token
                )
                message = "「\(folder.name)」から\(vimeoLibraryVideos.count)件の動画を取得しました。"
            } catch {
                vimeoLibraryVideos = []
                message = "Vimeoフォルダ内動画の取得に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func saveCommunityVideo(
        videoId: String,
        title: String,
        description: String,
        vimeoVideoId: String,
        vimeoURL: String,
        thumbnailURL: String,
        isPublished: Bool
    ) {
        guard let communityId = session.selectedCommunityId,
              let token = session.authenticationToken else { return }
        Task {
            do {
                try await repository.saveCommunityVideo(
                    communityId: communityId,
                    videoId: videoId,
                    title: title,
                    description: description,
                    vimeoVideoId: vimeoVideoId,
                    vimeoURL: vimeoURL,
                    thumbnailURL: thumbnailURL,
                    isPublished: isPublished,
                    idToken: token
                )
                message = "動画を保存しました。"
                await refreshManagement()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func saveAdministrator(_ adminUserId: String) {
        guard let communityId = session.selectedCommunityId,
              let actorUserId = session.authenticatedUserId,
              let token = session.authenticationToken else { return }
        guard isOwner else {
            message = "管理者の追加はOwnerのみが操作できます。"
            return
        }
        let normalized = adminUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            message = "管理者のユーザーIDを入力してください。"
            return
        }
        isLoading = true
        Task {
            do {
                try await repository.saveAdministrator(
                    communityId: communityId,
                    adminUserId: normalized,
                    role: "admin",
                    permissions: [CommunityAdminAccess.memberReviewPermission],
                    isActive: true,
                    actorUserId: actorUserId,
                    idToken: token
                )
                message = "管理者を追加しました。"
                await refreshManagement()
                isLoading = false
            } catch {
                isLoading = false
                message = error.localizedDescription
            }
        }
    }

    func deactivateAdministrator(_ admin: CommunityAdmin) {
        guard let communityId = session.selectedCommunityId,
              let actorUserId = session.authenticatedUserId,
              let token = session.authenticationToken else { return }
        guard isOwner else {
            message = "管理者の無効化はOwnerのみが操作できます。"
            return
        }
        guard admin.userId != session.authenticatedUserId else {
            message = "自分自身の管理者権限はこの画面から無効化できません。"
            return
        }
        Task {
            do {
                try await repository.saveAdministrator(
                    communityId: communityId,
                    adminUserId: admin.userId,
                    role: admin.role,
                    permissions: admin.permissions,
                    isActive: false,
                    actorUserId: actorUserId,
                    idToken: token
                )
                message = "管理者を無効化しました。"
                await refreshManagement()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func suspendMember(_ member: CommunityMembership) {
        review(
            member,
            status: .rejected,
            auditAction: "membership.suspended",
            successMessage: "会員を利用停止しました。"
        )
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
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var selection = 0

    var body: some View {
        VStack(spacing: 0) {
            if verticalSizeClass != .compact {
                Picker("つながる", selection: $selection) {
                    Text("コミュニティ").tag(0)
                    Text("投稿").tag(1)
                    Text("お知らせ").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.leading, 24)
                .padding(.trailing, 24)
                .padding(.top, 12)
            }
            if selection == 0 {
                CommunityRootView(model: communityModel, postModel: postModel)
            } else if selection == 1 {
                PostRootView(model: postModel)
            } else if selection == 2 {
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

private struct VimeoVideoDetailView: View {
    @ObservedObject var model: CommunityFeatureModel
    let video: DistributedVideo
    let onPlaybackChanged: (Double) -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var memoDraft = ""
    @State private var memoEditDrafts: [String: String] = [:]
    @State private var editingMemoIDs: Set<String> = []
    @State private var questionDraft = ""
    @State private var playbackSeconds: Double
    @State private var playbackDuration = 0.0
    @State private var playerCommand: VimeoPlayerCommand?
    @FocusState private var isMemoFocused: Bool
    @FocusState private var isQuestionFocused: Bool

    init(
        model: CommunityFeatureModel,
        video: DistributedVideo,
        initialPlaybackSeconds: Double,
        onPlaybackChanged: @escaping (Double) -> Void
    ) {
        self.model = model
        self.video = video
        self.onPlaybackChanged = onPlaybackChanged
        _playbackSeconds = State(initialValue: initialPlaybackSeconds)
    }

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VimeoPlayerView(
                            videoId: video.vimeoVideoId,
                            command: playerCommand,
                            initialPlaybackSeconds: playbackSeconds,
                            onTimeChanged: { seconds in
                                playbackSeconds = seconds
                                onPlaybackChanged(seconds)
                            },
                            onDurationChanged: { playbackDuration = $0 }
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: verticalSizeClass == .compact
                            ? viewport.size.height
                            : 210)
                        .id("selected-video-player")

                        if verticalSizeClass != .compact {
                            VimeoPlayerControlsView(
                                seekTo: { playerCommand = $0 },
                                playbackSeconds: $playbackSeconds,
                                duration: playbackDuration,
                                layout: .standard
                            )
                            Text("再生位置: \(Int(playbackSeconds) / 60):\(String(format: "%02d", Int(playbackSeconds) % 60))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(video.title)
                                .font(.headline)

                            Text("メモを追加")
                                .font(.subheadline.bold())
                            memoComposer(viewportWidth: viewport.size.width)
                            questionComposer(viewportWidth: viewport.size.width)
                            memoListSection
                        }
                    }
                    .padding(verticalSizeClass == .compact ? 0 : 16)
                }
                .scrollDisabled(verticalSizeClass == .compact)
                .onChange(of: verticalSizeClass) { _, newSizeClass in
                    guard newSizeClass != .compact else { return }
                    DispatchQueue.main.async {
                        scrollProxy.scrollTo("selected-video-player", anchor: .top)
                    }
                }
            }
        }
        .navigationTitle(verticalSizeClass == .compact ? "" : video.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(verticalSizeClass == .compact ? .hidden : .visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("キーボードを閉じる") {
                    isMemoFocused = false
                    isQuestionFocused = false
                }
            }
        }
        .statusBarHidden(verticalSizeClass == .compact)
        .onAppear { onPlaybackChanged(playbackSeconds) }
        .onDisappear { onPlaybackChanged(playbackSeconds) }
    }

    @ViewBuilder
    private func memoComposer(viewportWidth: CGFloat) -> some View {
        TextEditor(text: $memoDraft)
            .font(.body)
            .foregroundStyle(.primary)
            .focused($isMemoFocused)
            .frame(width: viewportWidth * 0.8, height: 110)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(8)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25))
            }
        Button("メモを追加") {
            model.addMemo(
                memoDraft,
                for: video,
                playbackSeconds: playbackSeconds
            )
            memoDraft = ""
            isMemoFocused = false
        }
        .buttonStyle(.borderedProminent)
        .disabled(memoDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @ViewBuilder
    private func questionComposer(viewportWidth: CGFloat) -> some View {
        Text("質問を送信")
            .font(.subheadline.bold())
        TextEditor(text: $questionDraft)
            .font(.body)
            .focused($isQuestionFocused)
            .frame(width: viewportWidth * 0.8, height: 90)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(8)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25))
            }
        Button("質問を送信") {
            model.submitVideoQuestion(
                questionDraft,
                memo: memoDraft,
                for: video,
                playbackSeconds: playbackSeconds
            )
            questionDraft = ""
            isQuestionFocused = false
        }
        .buttonStyle(.bordered)
        .disabled(questionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @ViewBuilder
    private var memoListSection: some View {
        ForEach(model.memos(for: video)) { entry in
            let editText = Binding<String>(
                get: { memoEditDrafts[entry.id] ?? entry.text },
                set: { memoEditDrafts[entry.id] = $0 }
            )
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.createdAt == .distantPast
                    ? "以前のメモ"
                    : "\(entry.createdAt.formatted(date: .abbreviated, time: .shortened)) / 再生位置 \(Int(entry.playbackSeconds) / 60):\(String(format: "%02d", Int(entry.playbackSeconds) % 60))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if editingMemoIDs.contains(entry.id) {
                    TextEditor(text: editText)
                        .frame(minHeight: 80)
                        .padding(6)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.25))
                        }
                    HStack {
                        Button("更新") {
                            model.updateMemo(entry, text: editText.wrappedValue, for: video)
                            editingMemoIDs.remove(entry.id)
                        }
                        Button("取消", role: .cancel) {
                            editingMemoIDs.remove(entry.id)
                        }
                    }
                } else {
                    Text(entry.text)
                    HStack {
                        Button("この位置から再生") {
                            playerCommand = VimeoPlayerCommand(
                                action: .seekAndPlay(entry.playbackSeconds)
                            )
                        }
                        .disabled(entry.createdAt == .distantPast)
                        Button("編集") {
                            memoEditDrafts[entry.id] = entry.text
                            editingMemoIDs.insert(entry.id)
                        }
                        Button("削除", role: .destructive) {
                            model.deleteMemo(entry, for: video)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct RadioSectionView: View {
    @ObservedObject var model: CommunityFeatureModel

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("インターネットラジオ").font(.title2.bold())
            if model.radioIsLoading {
                ProgressView()
            } else if model.radioPrograms.isEmpty {
                Text("ラジオ番組はありません。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.radioPrograms) { program in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(program.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(program.description)
                        Text("配信開始: \(formatter.string(from: program.broadcastStartAt))")
                        if let record = model.playbackRecord(for: program.id) {
                            Text(
                                "再生回数: \(record.playCount) 回 / 最終再生: "
                                    + (record.lastPlayedAt.map { formatter.string(from: $0) } ?? "未再生")
                            )
                            Text("再生位置: \(formatPosition(record.lastPositionSeconds))")
                        }
                        HStack(spacing: 8) {
                            Button(buttonTitle(for: program)) {
                                model.toggleRadioPlayback(program)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.radioIsLoading)
                            if model.radioPlayingProgramID == program.id {
                                Button(RadioPlaybackPresentation.stopAction) {
                                    model.stopRadioPlayback()
                                }
                                .buttonStyle(.bordered)
                                Text(RadioPlaybackPresentation.status(
                                    isPlaying: model.radioIsPlaying
                                ))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    Divider()
                }
            }
        }
    }

    private func buttonTitle(for program: RadioProgram) -> String {
        RadioPlaybackPresentation.primaryAction(
            isPlayable: model.isRadioPlayable(program),
            isActive: model.radioPlayingProgramID == program.id,
            isPlaying: model.radioIsPlaying
        )
    }

    private func formatPosition(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct CommunityRootView: View {
    @ObservedObject var model: CommunityFeatureModel
    @ObservedObject var postModel: PostFeatureModel
    let isManagementMode: Bool

    init(
        model: CommunityFeatureModel,
        postModel: PostFeatureModel,
        isManagementMode: Bool = false
    ) {
        self.model = model
        self.postModel = postModel
        self.isManagementMode = isManagementMode
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.openURL) private var openURL
    @State private var newAdminUserId = ""
    @State private var bookingEventID = ""
    @State private var bookingEventTitle = ""
    @State private var bookingEventDescription = ""
    @State private var bookingEventDate = Date()
    @State private var bookingEventFee = "0"
    @State private var bookingEventZoomURL = ""
    @State private var bookingSlotID = ""
    @State private var bookingSlotStartAt = Date()
    @State private var bookingSlotEndAt = Date().addingTimeInterval(3_600)
    @State private var bookingSlotCapacity = "1"
    @State private var bookingSlotOpen = true
    @State private var bookingCancellationSlotID: String?
    @State private var videoMemoDrafts: [String: String] = [:]
    @State private var videoMemoEditDrafts: [String: String] = [:]
    @State private var editingVideoMemoIDs: Set<String> = []
    @State private var videoQuestionDrafts: [String: String] = [:]
    @State private var adminVideoQuestionDrafts: [String: String] = [:]
    @State private var videoPlaybackPositions: [String: Double] = [:]
    @State private var videoPlaybackDurations: [String: Double] = [:]
    @State private var videoPlayerCommands: [String: VimeoPlayerCommand] = [:]
    @SceneStorage("activeVimeoVideoID") private var activeVideoID = ""
    @SceneStorage("activeVimeoPlaybackSeconds") private var activePlaybackSeconds = 0.0
    @FocusState private var isVideoMemoFocused: Bool
    @FocusState private var isVideoQuestionFocused: Bool
    @State private var landscapeViewportHeight: CGFloat = 0
    @State private var pendingVideoScrollID: String?

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                ScrollViewReader { scrollProxy in
                    ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isManagementMode {
                        if model.isLoading { ProgressView() }
                        if let message = model.message {
                            Text(message)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        if model.canReviewMembers {
                            Text("運営モード").font(.title2.bold())
                            managementPostSection
                            applicationReviewSection
                        } else {
                            ContentUnavailableView(
                                "運営権限がありません",
                                systemImage: "person.crop.circle.badge.exclamationmark",
                                description: Text("運営者向け権限を持つアカウントでのみ利用できます。")
                            )
                        }
                    } else {
                        if model.isLoading { ProgressView() }
                        if let message = model.message {
                            Text(message)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        if model.canAccessRadio {
                            RadioSectionView(model: model)
                        }
                        if verticalSizeClass != .compact {
                            publicCommunitySection
                            if !model.isLoggedIn {
                                ContentUnavailableView(
                                    "ログインが必要です",
                                    systemImage: "person.crop.circle.badge.exclamationmark",
                                    description: Text("マイページで会員登録またはログイン後に参加申請できます。")
                                )
                            } else {
                                membershipSection
                                if model.canReviewMembers {
                                    applicationReviewSection
                                }
                            }
                        }
                        if model.isLoggedIn {
                            bookingSection
                        }
                        if model.isLoggedIn, !model.distributedVideos.isEmpty {
                            videoSelectionSection
                        }
                        if verticalSizeClass != .compact, model.isLoggedIn {
                            joinSection
                        }
                    }
                }
                .padding(verticalSizeClass == .compact ? 12 : 24)
                    }
                .navigationTitle(isManagementMode ? "運営モード" : (verticalSizeClass == .compact ? "" : "つながる"))
                .toolbar(verticalSizeClass == .compact ? .hidden : .visible, for: .navigationBar)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("キーボードを閉じる") {
                            isVideoMemoFocused = false
                            isVideoQuestionFocused = false
                        }
                    }
                }
                .task {
                    model.refreshPublicCommunities()
                    await model.refresh()
                    if isManagementMode {
                        postModel.refreshManagementMemberPosts()
                    }
                }
                .sheet(isPresented: $model.showsScanner) {
                    CommunityQRScanner { model.receivedScan($0) }
                }
                .onAppear {
                    landscapeViewportHeight = viewport.size.height
                }
                .onChange(of: viewport.size) { _, newSize in
                    landscapeViewportHeight = newSize.height
                }
                .onChange(of: verticalSizeClass) { _, newSizeClass in
                    guard newSizeClass != .compact else { return }
                    let videoID = activeVideoID.isEmpty
                        ? model.distributedVideos.first?.id
                        : activeVideoID
                    guard let videoID else { return }
                    pendingVideoScrollID = videoID
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        guard pendingVideoScrollID == videoID else { return }
                        scrollProxy.scrollTo(videoID, anchor: .top)
                        pendingVideoScrollID = nil
                    }
                }
                .onChange(of: model.session.selectedCommunityId) { _, _ in
                    if isManagementMode {
                        postModel.refreshManagementMemberPosts()
                    }
                    Task { await model.refreshRadioPrograms() }
                }
                .onChange(of: model.session.authenticationToken) { _, token in
                    if token == nil {
                        Task { await model.refreshRadioPrograms() }
                    }
                }
                }
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

    private var managementPostSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("会員投稿への返信").font(.title3.bold())
            if let selectedPost = postModel.selectedManagementMemberPost {
                VStack(alignment: .leading, spacing: 8) {
                    Text("対象投稿: \(selectedPost.title)")
                        .font(.headline)
                    Text("投稿者: \(selectedPost.authorName)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(selectedPost.body)
                        .lineLimit(3)
                        .foregroundStyle(.secondary)
                    Text("管理者返信")
                    TextField("返信を入力", text: $postModel.managementReplyDraft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("返信を保存") { postModel.saveManagementReply() }
                            .buttonStyle(.borderedProminent)
                        Button("編集をやめる") { postModel.closeManagementReply() }
                            .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                let unanswered = postModel.managementMemberPosts.filter {
                    ($0.legacyAdminReply ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                if unanswered.isEmpty {
                    Text("未返信の投稿はありません。").foregroundStyle(.secondary)
                } else {
                    Text("未返信").font(.headline)
                    ForEach(unanswered) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("投稿者: \(post.authorName)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(post.title)
                                .font(.headline)
                            Text(post.body)
                                .lineLimit(3)
                                .foregroundStyle(.secondary)
                            Button("返信を入力") { postModel.startManagementReply(for: post) }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                let answered = postModel.managementMemberPosts.filter {
                    !($0.legacyAdminReply ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                if !answered.isEmpty {
                    Text("回答済み").font(.headline)
                    ForEach(answered) { post in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("投稿者: \(post.authorName)")
                                Spacer()
                                if post.hasUnreadReply {
                                    Text("新着")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            Text(post.title)
                                .font(.headline)
                            Text("返信: \((post.legacyAdminReply ?? "").isEmpty ? "（未入力）" : post.legacyAdminReply ?? "")")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
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
            Text("管理者コンソール").font(.title3.bold())
            Text("イベント予約の管理").font(.headline)
            TextField("イベント名", text: $bookingEventTitle)
                .textFieldStyle(.roundedBorder)
            TextField("説明", text: $bookingEventDescription, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            DatePicker("開催日時", selection: $bookingEventDate)
            TextField("料金（円）", text: $bookingEventFee)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
            TextField("Zoom URL（任意）", text: $bookingEventZoomURL)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            HStack {
                Button("下書き保存") {
                    model.saveBookingEvent(
                        eventID: bookingEventID,
                        title: bookingEventTitle,
                        description: bookingEventDescription,
                        eventDate: bookingEventDate,
                        feeAmount: Int(bookingEventFee) ?? 0,
                        paymentRequired: (Int(bookingEventFee) ?? 0) > 0,
                        zoomURL: bookingEventZoomURL,
                        isPublished: false
                    )
                }
                .buttonStyle(.bordered)
                Button("公開して保存") {
                    model.saveBookingEvent(
                        eventID: bookingEventID,
                        title: bookingEventTitle,
                        description: bookingEventDescription,
                        eventDate: bookingEventDate,
                        feeAmount: Int(bookingEventFee) ?? 0,
                        paymentRequired: (Int(bookingEventFee) ?? 0) > 0,
                        zoomURL: bookingEventZoomURL,
                        isPublished: true
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            ForEach(model.managedBookingEvents) { event in
                Button("\(event.title)（\(event.isPublished ? "公開" : "下書き")）") {
                    Task { await model.selectManagedBookingEvent(event.id) }
                    bookingEventID = event.id
                    bookingEventTitle = event.title
                    bookingEventDescription = event.description
                    bookingEventDate = event.eventDate ?? Date()
                    bookingEventFee = String(event.feeAmount)
                    bookingEventZoomURL = event.zoomURL?.absoluteString ?? ""
                }
                .buttonStyle(.plain)
            }
            if model.selectedManagedBookingEventID != nil {
                Text("予約状況").font(.headline)
                Button("予約情報を更新") {
                    model.refreshBookingStatus()
                }
                .buttonStyle(.bordered)
                if model.managedBookingSlots.isEmpty {
                    Text("予約枠はまだありません。")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.managedBookingSlots) { slot in
                    let reservations = model.managedBookingReservations.filter { $0.slotId == slot.id }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(slot.startAt?.formatted(date: .abbreviated, time: .shortened) ?? "開始時刻未定") - \(slot.endAt?.formatted(date: .omitted, time: .shortened) ?? "終了時刻未定")")
                        Text("定員 \(slot.capacity)名 / 予約 \(slot.reservedCount)名 / 残席 \(slot.remainingCount)名")
                            .font(.subheadline)
                        Text(slot.isOpen ? "受付中" : "受付停止中")
                            .font(.subheadline)
                        ForEach(reservations, id: \.userId) { reservation in
                            let memberName = model.communityMembers.first {
                                $0.userId == reservation.userId
                            }?.applicantName ?? reservation.userId
                            Text("\(memberName) / \(reservation.status) / \(reservation.purchaseStatus)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            Text("予約枠を保存").font(.headline)
            TextField("イベントID（上のイベントを選択）", text: $bookingEventID)
                .textFieldStyle(.roundedBorder)
            DatePicker("開始日時", selection: $bookingSlotStartAt)
            DatePicker("終了日時", selection: $bookingSlotEndAt)
            TextField("定員", text: $bookingSlotCapacity)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
            Toggle("予約受付を開始する", isOn: $bookingSlotOpen)
            Button("予約枠を保存") {
                model.saveBookingSlot(
                    eventID: bookingEventID,
                    slotID: bookingSlotID,
                    startAt: bookingSlotStartAt,
                    endAt: bookingSlotEndAt,
                    capacity: Int(bookingSlotCapacity) ?? 0,
                    isOpen: bookingSlotOpen
                )
            }
            .buttonStyle(.borderedProminent)
            if model.isOwner {
                Text("複数管理者の設定")
                TextField("氏名・メールアドレス・UIDで検索", text: $model.adminQuery)
                    .textFieldStyle(.roundedBorder)
                if model.administratorCandidates.isEmpty {
                    Text("追加できる承認済み会員が見つかりません。")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.administratorCandidates) { member in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(member.applicantName ?? "氏名未登録")
                            Text(member.applicantEmail ?? member.userId)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("管理者に追加") {
                            model.saveAdministrator(member.userId)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isLoading)
                    }
                }
                ForEach(model.administrators) { admin in
                    HStack {
                        Text("\(admin.userId) (\(admin.role))")
                            .font(.footnote)
                            .textSelection(.enabled)
                        Spacer()
                        if admin.isActive {
                            Button("無効化") { model.deactivateAdministrator(admin) }
                                .buttonStyle(.bordered)
                        } else {
                            Text("無効").foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("管理者の追加・無効化はOwnerのみが操作できます。")
                    .foregroundStyle(.secondary)
            }
            Text("会員管理").font(.title3.bold())
            ForEach(model.communityMembers) { member in
                HStack {
                    VStack(alignment: .leading) {
                        Text(member.applicantName ?? member.userId)
                        Text(adminMemberStatusText(member))
                            .font(.footnote)
                            .foregroundStyle(statusColor(member.status))
                    }
                    Spacer()
                    if member.status == .approved {
                        Button("利用停止") { model.suspendMember(member) }
                            .buttonStyle(.bordered)
                    }
                }
            }
            Text("動画質問対応").font(.title3.bold())
            let unansweredQuestions = model.adminVideoQuestions.filter {
                $0.answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if unansweredQuestions.isEmpty {
                Text("対応する質問はありません。")
                    .foregroundStyle(.secondary)
            } else {
                Text("未回答").font(.headline)
                ForEach(unansweredQuestions) { question in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("動画: \(question.videoTitle)")
                            .font(.headline)
                        Text("質問: \(question.questionText)")
                        if !question.memoText.isEmpty {
                            Text("メモ: \(question.memoText)")
                                .foregroundStyle(.secondary)
                        }
                        TextField("回答を入力", text: Binding(
                            get: { adminVideoQuestionDrafts[question.id] ?? "" },
                            set: { adminVideoQuestionDrafts[question.id] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("回答を保存") {
                                model.answerVideoQuestion(
                                    question.id,
                                    answer: adminVideoQuestionDrafts[question.id] ?? ""
                                )
                                adminVideoQuestionDrafts[question.id] = nil
                            }
                            .buttonStyle(.borderedProminent)
                            Button("クリア") {
                                adminVideoQuestionDrafts[question.id] = ""
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            let answeredQuestions = model.adminVideoQuestions.filter {
                !$0.answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if !answeredQuestions.isEmpty {
                Text("回答済み").font(.headline)
            }
            ForEach(answeredQuestions) { question in
                VStack(alignment: .leading, spacing: 4) {
                    Text("動画: \(question.videoTitle)")
                        .font(.headline)
                    Text("質問: \(question.questionText)")
                    if !question.memoText.isEmpty {
                        Text("メモ: \(question.memoText)")
                            .foregroundStyle(.secondary)
                    }
                    Text("回答: \(question.answerText)")
                }
                .padding()
                .background(.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text("監査ログ").font(.title3.bold())
            if model.auditLogs.isEmpty {
                Text("監査ログはまだありません。")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.auditLogs, id: \.id) { log in
                VStack(alignment: .leading, spacing: 4) {
                    Text(auditActionText(log.action)).font(.headline)
                    HStack {
                        if let actorUserId = log.actorUserId, !actorUserId.isEmpty {
                            Text("操作: \(actorUserId)")
                        }
                        if let targetUserId = log.targetUserId, !targetUserId.isEmpty {
                            Text("対象: \(targetUserId)")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    if let createdAt = log.createdAt {
                        Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            AdminVideoManagementSection(model: model)
        }
    }

    private struct AdminVideoManagementSection: View {
        @ObservedObject var model: CommunityFeatureModel
        @State private var videoId = ""
        @State private var title = ""
        @State private var description = ""
        @State private var vimeoVideoId = ""
        @State private var vimeoURL = ""
        @State private var thumbnailURL = ""
        @State private var vimeoAccessToken = ""
        @State private var selectedVimeoVideoIDs: Set<String> = []
        @State private var vimeoUserID = ""
        @State private var vimeoQuery = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Vimeo動画管理").font(.title3.bold())
                Text("Vimeo接続設定").font(.headline)
                Text(model.vimeoConfiguration.hasAccessToken ? "接続設定済み" : "未設定")
                    .font(.footnote)
                    .foregroundStyle(model.vimeoConfiguration.hasAccessToken ? .green : .secondary)
                SecureField("Vimeoアクセストークン", text: $vimeoAccessToken)
                    .textFieldStyle(.roundedBorder)
                TextField("VimeoユーザーID", text: $vimeoUserID)
                    .textFieldStyle(.roundedBorder)
                TextField("動画検索キーワード（任意）", text: $vimeoQuery)
                    .textFieldStyle(.roundedBorder)
                Button("Vimeo接続設定を保存") {
                    model.saveVimeoConfiguration(
                        accessToken: vimeoAccessToken,
                        userId: vimeoUserID,
                        query: vimeoQuery
                    )
                    vimeoAccessToken = ""
                }
                .buttonStyle(.bordered)
                Divider()
                HStack {
                    Text("Vimeoフォルダ").font(.headline)
                    Spacer()
                    Button("フォルダを取得") { model.refreshVimeoFolders() }
                        .buttonStyle(.bordered)
                }
                if !model.vimeoFolders.isEmpty {
                    Button("すべての動画を取得") { model.refreshVimeoLibrary() }
                        .buttonStyle(.bordered)
                    ForEach(model.vimeoFolders) { folder in
                        Button(folder.name) { model.refreshVimeoFolderVideos(folder: folder) }
                            .buttonStyle(.bordered)
                    }
                }
                HStack {
                    Text("Vimeo動画一覧").font(.headline)
                    Spacer()
                    Button("Vimeoから取得") { model.refreshVimeoLibrary() }
                        .buttonStyle(.bordered)
                }
                if model.vimeoLibraryVideos.isEmpty {
                    Text("Vimeoから取得すると、動画を選択して登録できます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if !model.vimeoLibraryVideos.isEmpty {
                    Text("複数選択して一括公開")
                        .font(.headline)
                    ForEach(model.vimeoLibraryVideos) { video in
                        Toggle(video.title, isOn: Binding(
                            get: { selectedVimeoVideoIDs.contains(video.vimeoVideoId) },
                            set: { isSelected in
                                if isSelected {
                                    selectedVimeoVideoIDs.insert(video.vimeoVideoId)
                                } else {
                                    selectedVimeoVideoIDs.remove(video.vimeoVideoId)
                                }
                            }
                        ))
                    }
                    Button("選択した動画をまとめて公開") {
                        let selectedVideos = model.vimeoLibraryVideos.filter {
                            selectedVimeoVideoIDs.contains($0.vimeoVideoId)
                        }
                        model.saveCommunityVideos(selectedVideos, isPublished: true)
                        selectedVimeoVideoIDs.removeAll()
                        model.clearVimeoLibrary()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedVimeoVideoIDs.isEmpty)
                    Text("個別にタイトルや説明を編集する場合は、下の動画を選択してください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.vimeoLibraryVideos) { video in
                    Button {
                        videoId = video.vimeoVideoId
                        title = video.title
                        description = video.description
                        vimeoVideoId = video.vimeoVideoId
                        vimeoURL = video.videoURL?.absoluteString ?? ""
                        thumbnailURL = video.thumbnailURL?.absoluteString ?? ""
                        model.clearVimeoLibrary()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(video.title).foregroundStyle(.primary)
                                Text(video.vimeoVideoId)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(model.managedVideos.contains(where: { $0.vimeoVideoId == video.vimeoVideoId }) ? "登録済み" : "選択")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Divider()
                Text("登録済み動画").font(.headline)
                ForEach(model.managedVideos) { video in
                    HStack {
                        Button(video.title) {
                            videoId = video.id
                            title = video.title
                            description = video.description
                            vimeoVideoId = video.vimeoVideoId
                            vimeoURL = video.videoURL?.absoluteString ?? ""
                            thumbnailURL = video.thumbnailURL?.absoluteString ?? ""
                        }
                        Spacer()
                        Text(video.isPublished ? "公開" : "下書き")
                            .foregroundStyle(.secondary)
                        Button(video.isPublished ? "非公開" : "公開") {
                            model.saveCommunityVideo(
                                videoId: video.id,
                                title: video.title,
                                description: video.description,
                                vimeoVideoId: video.vimeoVideoId,
                                vimeoURL: video.videoURL?.absoluteString ?? "",
                                thumbnailURL: video.thumbnailURL?.absoluteString ?? "",
                                isPublished: !video.isPublished
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                }
                TextField("動画ID（編集時のみ）", text: $videoId)
                    .textFieldStyle(.roundedBorder)
                TextField("動画タイトル", text: $title)
                    .textFieldStyle(.roundedBorder)
                TextField("Vimeo動画ID", text: $vimeoVideoId)
                    .textFieldStyle(.roundedBorder)
                TextField("Vimeo URL（任意）", text: $vimeoURL)
                    .textFieldStyle(.roundedBorder)
                TextField("説明", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
                TextField("サムネイルURL（任意）", text: $thumbnailURL)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("下書き保存") { save(isPublished: false) }
                    Button("公開して保存") { save(isPublished: true) }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onChange(of: model.vimeoConfiguration) { configuration in
                vimeoUserID = configuration.userId
                vimeoQuery = configuration.query
            }
        }

        private func save(isPublished: Bool) {
            model.saveCommunityVideo(
                videoId: videoId,
                title: title,
                description: description,
                vimeoVideoId: vimeoVideoId,
                vimeoURL: vimeoURL,
                thumbnailURL: thumbnailURL,
                isPublished: isPublished
            )
        }
    }

    private func videoPlayerControls(
        for video: DistributedVideo,
        playbackSeconds: Binding<Double>,
        durationSeconds: Double,
        layout: VimeoPlayerControlsView.Layout = .standard
    ) -> some View {
        VimeoPlayerControlsView(
            seekTo: { command in
                videoPlayerCommands[video.id] = command
            },
            playbackSeconds: playbackSeconds,
            duration: durationSeconds,
            layout: layout
        )
    }

    private var bookingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.bookingEvents.isEmpty {
                Text("イベント予約")
                    .font(.title2.bold())
                Button("予約情報を更新") {
                    model.refreshBookingStatus()
                }
                .buttonStyle(.bordered)
                if !model.myBookingReservations.isEmpty {
                    Text("自分の予約")
                        .font(.headline)
                    ForEach(model.myBookingReservations, id: \.slotId) { reservation in
                        let event = model.bookingEvents.first { $0.id == reservation.eventId }
                        let slot = model.myBookingSlots["\(reservation.eventId):\(reservation.slotId)"]
                        Text(
                            "\(event?.title ?? "イベント") / " +
                                (slot?.startAt?.formatted(date: .abbreviated, time: .shortened) ?? "予約枠: \(reservation.slotId)")
                        )
                            .foregroundStyle(.secondary)
                        Button("予約内容を確認") {
                            Task { await model.selectBookingEvent(reservation.eventId) }
                        }
                        .buttonStyle(.bordered)
                        if event != nil, slot != nil {
                            Button("予約をキャンセル", role: .destructive) {
                                Task {
                                    await model.selectBookingEvent(reservation.eventId)
                                    bookingCancellationSlotID = reservation.slotId
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.bookingProcessingSlotID != nil)
                        }
                    }
                }
                ForEach(model.bookingEvents) { event in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.headline)
                        if let eventDate = event.eventDate {
                            Text("開催日: \(eventDate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if !event.description.isEmpty {
                            Text(event.description)
                        }
                        if model.myBookingReservations.contains(where: { $0.eventId == event.id }) {
                            Text("このイベントは予約済みです。")
                                .foregroundStyle(.secondary)
                        }
                        Text(
                            event.paymentRequired || event.feeAmount > 0
                                ? "料金: \(event.feeAmount)円（決済準備中のため予約できません）"
                                : "無料イベント"
                        )
                        if model.myBookingReservations.contains(where: { $0.eventId == event.id }),
                           let zoomURL = event.zoomURL {
                            Button("Zoom参加リンクを開く") {
                                openURL(zoomURL)
                            }
                            .buttonStyle(.bordered)
                        }
                        Button(
                            model.selectedBookingEventID == event.id ? "予約枠を表示中" : "予約枠を見る"
                        ) {
                            Task { await model.selectBookingEvent(event.id) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.selectedBookingEventID == event.id)

                        if model.selectedBookingEventID == event.id {
                            if model.bookingSlots.isEmpty {
                                Text("予約枠はまだありません。")
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(model.bookingSlots) { slot in
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(slot.startAt?.formatted(date: .abbreviated, time: .shortened) ?? "開始時刻未定") - \(slot.endAt?.formatted(date: .omitted, time: .shortened) ?? "終了時刻未定")")
                                        Text("残席: \(slot.remainingCount) / \(slot.capacity)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    let isBooked = model.bookedSlotIDs.contains(slot.id)
                                    if isBooked {
                                        Button("予約をキャンセル") {
                                            bookingCancellationSlotID = slot.id
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(model.bookingProcessingSlotID != nil)
                                        .confirmationDialog(
                                            "予約をキャンセルしますか？",
                                            isPresented: Binding(
                                                get: { bookingCancellationSlotID == slot.id },
                                                set: { if !$0 { bookingCancellationSlotID = nil } }
                                            ),
                                            titleVisibility: .visible
                                        ) {
                                            Button("予約をキャンセル", role: .destructive) {
                                                bookingCancellationSlotID = nil
                                                Task { await model.cancelBooking(event: event, slot: slot) }
                                            }
                                            Button("戻る", role: .cancel) {
                                                bookingCancellationSlotID = nil
                                            }
                                        } message: {
                                            Text("この操作を取り消すことはできません。")
                                        }
                                    } else {
                                        let bookingLabel = event.paymentRequired || event.feeAmount > 0
                                            ? "決済準備中"
                                            : !slot.isOpen ? "受付停止中" : slot.isFull ? "満席" : "予約"
                                        Button(bookingLabel) {
                                            Task { await model.reserveBooking(event: event, slot: slot) }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(
                                            event.paymentRequired || event.feeAmount > 0 ||
                                                !slot.isOpen || slot.isFull ||
                                                model.bookingProcessingSlotID != nil
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var videoSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vimeo配信動画")
                .font(.title2.bold())
            ForEach(model.distributedVideos) { video in
                NavigationLink {
                    VimeoVideoDetailView(
                        model: model,
                        video: video,
                        initialPlaybackSeconds: activeVideoID == video.id
                            ? activePlaybackSeconds
                            : (videoPlaybackPositions[video.vimeoVideoId] ?? 0),
                        onPlaybackChanged: { seconds in
                            videoPlaybackPositions[video.vimeoVideoId] = seconds
                            activeVideoID = video.id
                            activePlaybackSeconds = seconds
                        }
                    )
                } label: {
                    HStack(spacing: 14) {
                        AsyncImage(url: video.thumbnailURL) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ZStack {
                                Color.secondary.opacity(0.12)
                                Image(systemName: "play.rectangle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 120, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 5) {
                            Text(video.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Text("視聴・メモ")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .id(video.id)
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

    private func adminMemberStatusText(_ member: CommunityMembership) -> String {
        switch member.status {
        case .pending:
            "承認待ち"
        case .approved:
            "参加中"
        case .rejected:
            member.joinedAt == nil ? "承認されませんでした" : "利用停止中"
        }
    }

    private func auditActionText(_ action: String) -> String {
        switch action {
        case "membership.approved":
            "参加申請承認"
        case "membership.rejected":
            "参加申請却下"
        case "membership.suspended":
            "会員を利用停止"
        case "administrator.added":
            "管理者を追加"
        case "administrator.deactivated":
            "管理者を無効化"
        default:
            action
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
        case adminMode
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

    func logout() {
        session.logout()
        accessState = .guest
        screen = .overview
        message = "ログアウトしました。"
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
    @ObservedObject var communityModel: CommunityFeatureModel
    @ObservedObject var postModel: PostFeatureModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch model.screen {
                    case .overview:
                        overview
                    case .adminMode:
                        ManagementModeRoot(
                            model: model,
                            communityModel: communityModel,
                            postModel: postModel,
                        )
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
                Button("ログアウト") { model.logout() }
                    .buttonStyle(.bordered)
            case .registered:
                Text("ログイン済みです。「つながる」からコミュニティコードまたはQRコードで参加申請できます。")
                Button("ログアウト") { model.logout() }
                    .buttonStyle(.bordered)
            case .rejected:
                Text("コミュニティへの参加申請は承認されませんでした。申請先へご確認ください。")
                Button("別のアカウントでログイン") { model.show(.login) }
                    .buttonStyle(.bordered)
                Button("ログアウト") { model.logout() }
                    .buttonStyle(.bordered)
            case .member:
                Text("会員としてログインしています。参加中のコミュニティ機能を利用できます。")
                if communityModel.canReviewMembers {
                    Button("運営モードへ入る") { model.show(.adminMode) }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
                Button("ログアウト") { model.logout() }
                    .buttonStyle(.bordered)
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

private struct ManagementModeRoot: View {
    @ObservedObject var model: AccountFeatureModel
    @ObservedObject var communityModel: CommunityFeatureModel
    @ObservedObject var postModel: PostFeatureModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("マイページへ戻る") {
                model.show(.overview)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            CommunityRootView(
                model: communityModel,
                postModel: postModel,
                isManagementMode: true
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
