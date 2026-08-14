import DesignSystem
import Model
import SwiftUI
import Foundation
import WebKit

public struct ToolsHubView: View {
    private enum Destination: Identifiable {
        case schedule
        case diary
        case denomination
        case meetingMinutes
        case snsPostingAssistant
        case favorites
        case friends
        case manual
        case distributedVideos
        case distributedVideoPlayer(DistributedVideo)

        var id: String {
            switch self {
            case .schedule: "schedule"
            case .diary: "diary"
            case .denomination: "denomination"
            case .meetingMinutes: "meetingMinutes"
            case .snsPostingAssistant: "snsPostingAssistant"
            case .favorites: "favorites"
            case .friends: "friends"
            case .manual: "manual"
            case .distributedVideos: "distributedVideos"
            case let .distributedVideoPlayer(video): "distributedVideoPlayer:\(video.id)"
            }
        }
    }

    @ObservedObject private var scheduleModel: ScheduleFeatureModel
    @ObservedObject private var diaryModel: DiaryFeatureModel
    @ObservedObject private var cashDistributionModel: CashDistributionFeatureModel
    @ObservedObject private var meetingMinutesModel: MeetingMinutesFeatureModel
    @ObservedObject private var snsPostingAssistantModel: SnsPostingAssistantFeatureModel
    @ObservedObject private var favoriteBookmarkModel: FavoriteBookmarkFeatureModel
    @ObservedObject private var friendExchangeModel: FriendExchangeFeatureModel
    @ObservedObject private var distributedVideoModel: DistributedVideoFeatureModel
    @State private var destination: Destination?
    public init(
        scheduleModel: ScheduleFeatureModel,
        diaryModel: DiaryFeatureModel,
        cashDistributionModel: CashDistributionFeatureModel,
        meetingMinutesModel: MeetingMinutesFeatureModel,
        snsPostingAssistantModel: SnsPostingAssistantFeatureModel,
        favoriteBookmarkModel: FavoriteBookmarkFeatureModel,
        friendExchangeModel: FriendExchangeFeatureModel,
        distributedVideoModel: DistributedVideoFeatureModel
    ) {
        self.scheduleModel = scheduleModel
        self.diaryModel = diaryModel
        self.cashDistributionModel = cashDistributionModel
        self.meetingMinutesModel = meetingMinutesModel
        self.snsPostingAssistantModel = snsPostingAssistantModel
        self.favoriteBookmarkModel = favoriteBookmarkModel
        self.friendExchangeModel = friendExchangeModel
        self.distributedVideoModel = distributedVideoModel
    }

    public var body: some View {
        NavigationStack {
            List {
                Button {
                    destination = .schedule
                } label: {
                    FeatureCard(
                        "screen.schedule.list",
                        subtitle: "home.schedule.subtitle",
                        systemImage: "calendar"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .meetingMinutes
                } label: {
                    FeatureCard(
                        "home.meeting_minutes.title",
                        subtitle: "home.meeting_minutes.subtitle",
                        systemImage: "mic"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .diary
                } label: {
                    FeatureCard(
                        "screen.diary.list",
                        subtitle: "home.diary.subtitle",
                        systemImage: "book.closed"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .denomination
                } label: {
                    FeatureCard(
                        "home.denomination.title",
                        subtitle: "home.denomination.subtitle",
                        systemImage: "yensign.circle"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .snsPostingAssistant
                } label: {
                    FeatureCard(
                        "SNS投稿補助",
                        subtitle: "文章をコピーして外部SNSを開きます。",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .favorites
                } label: {
                    FeatureCard(
                        "お気に入り",
                        subtitle: "よく見るWebページを自分専用に保存します。",
                        systemImage: "bookmark"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .distributedVideos
                } label: {
                    FeatureCard(
                        "配信動画",
                        subtitle: "Vimeo配信動画を一覧で開き再生できます。",
                        systemImage: "play.rectangle"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .friends
                } label: {
                    FeatureCard(
                        "友達情報・交流履歴帳",
                        subtitle: "本人だけが見られる友達情報と交流履歴を端末内に保存します。",
                        systemImage: "person.2"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .manual
                } label: {
                    FeatureCard(
                        "使い方マニュアル",
                        subtitle: "アプリの主要機能をすばやく確認できます。",
                        systemImage: "book.closed"
                    )
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("tab.tools")
        }
        .sheet(item: $destination) { destination in
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        self.destination = nil
                    } label: {
                        Label("action.close", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                switch destination {
                case .schedule:
                    ScheduleListView(model: scheduleModel)
                case .diary:
                    DiaryRootView(model: diaryModel)
                case .denomination:
                    DenominationToolView(model: cashDistributionModel)
                case .meetingMinutes:
                    MeetingMinutesRootView(model: meetingMinutesModel)
                case .snsPostingAssistant:
                    SnsPostingAssistantView(model: snsPostingAssistantModel)
                case .favorites:
                    FavoriteBookmarksView(model: favoriteBookmarkModel)
                case .friends:
                    FriendExchangeRootView(model: friendExchangeModel)
                case .manual:
                    ManualListView()
                case .distributedVideos:
                    DistributedVideoListRoot(
                        model: distributedVideoModel,
                        onSelect: { self.destination = .distributedVideoPlayer($0) },
                    )
                case let .distributedVideoPlayer(video):
                    DistributedVideoPlayerView(
                        model: distributedVideoModel,
                        video: video,
                        onBackToList: {
                            self.destination = .distributedVideos
                        }
                    )
                }
            }
        }
    }
}

private struct DistributedVideoListRoot: View {
    @ObservedObject var model: DistributedVideoFeatureModel
    let onSelect: (DistributedVideo) -> Void

    var body: some View {
        Group {
            if model.hasPendingVideoMemoSync {
                OfflineBanner()
            }
            if model.isLoading && model.videos.isEmpty {
                LoadingState()
            } else if let message = model.errorMessage, model.videos.isEmpty {
                ErrorState(message: message) {
                    Task {
                        await model.load()
                    }
                }
            } else if model.videos.isEmpty {
                EmptyState("配信動画はまだありません", systemImage: "play.rectangle")
            } else {
                List {
                    ForEach(model.videos) { video in
                        Button {
                            onSelect(video)
                        } label: {
                            DistributedVideoCell(video: video)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("配信動画")
        .task {
            await model.load()
        }
    }
}

private struct DistributedVideoPlayerView: View {
    @ObservedObject var model: DistributedVideoFeatureModel
    let video: DistributedVideo
    let onBackToList: () -> Void
    @State private var memoText = ""
    @State private var editingMemoId: String?
    @State private var editingMemoText = ""
    @State private var questionText = ""
    @State private var memoCsvURL: URL?
    @State private var questionCsvURL: URL?
    @State private var showMemoCsvEmptyState = false
    @State private var showQuestionCsvEmptyState = false
    @State private var playbackSeconds = 0.0
    @State private var playbackCommand: VimeoPlaybackCommand?
    @State private var playbackCommandId = 0
    private let memoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    onBackToList()
                } label: {
                    Label("一覧へ戻る", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            if model.hasPendingVideoMemoSync {
                OfflineBanner()
            }

            if let videoId = distributedVimeoVideoId(for: video) {
                DistributedVimeoVideoPlayerView(
                    videoId: videoId,
                    initialPlaybackSeconds: playbackSeconds,
                    command: playbackCommand,
                    onPlaybackTimeChanged: { playbackSeconds = $0 },
                )
                .frame(height: 220)

                VStack(alignment: .leading, spacing: 12) {
                    Button("現在の再生位置を取得") {
                        sendPlaybackCommand(.reportCurrentTime)
                    }
                    .buttonStyle(.bordered)

                    Text("再生位置: \(playbackTimeLabel(playbackSeconds))")
                        .font(.headline)

                    Divider()

                    Text("メモ")
                        .font(.headline)
                    HStack {
                        Button("CSV共有") {
                            let memos = model.videoMemosFor(video)
                            if memos.isEmpty {
                                showMemoCsvEmptyState = true
                                return
                            }
                            showMemoCsvEmptyState = false
                            memoCsvURL = makeMemoCsvURL(video: video, memos: memos)
                        }
                        Spacer()
                    }
                    TextField("動画メモ", text: $memoText, axis: .vertical)
                        .lineLimit(4...12)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("メモを追加") {
                            model.addVideoMemo(video, memo: memoText, playbackSeconds: playbackSeconds)
                            memoText = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if !memoText.isEmpty {
                            Button("クリア") {
                                memoText = ""
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if model.videoMemosFor(video).isEmpty {
                        if showMemoCsvEmptyState {
                            EmptyState("CSV共有対象のメモがありません")
                        } else {
                            Text("まだメモはありません。")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(model.videoMemosFor(video)) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(
                                    item.createdAtMillis == 0
                                        ? "以前のメモ"
                                        : "\(memoDateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(item.createdAtMillis) / 1000))) / 再生位置 \(playbackTimeLabel(item.playbackSeconds))"
                                )
                                if editingMemoId == item.id {
                                    TextField("動画メモ", text: $editingMemoText, axis: .vertical)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(4...12)
                                    HStack {
                                        Button("更新") {
                                            model.updateVideoMemo(video, memo: item, text: editingMemoText)
                                            editingMemoId = nil
                                        }
                                        .buttonStyle(.bordered)
                                        Button("取消") {
                                            editingMemoId = nil
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                } else {
                                    Text(item.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    HStack {
                                        Button("この位置から再生") {
                                            sendPlaybackCommand(.seekAndPlay(item.playbackSeconds))
                                        }
                                        .buttonStyle(.bordered)

                                        Button("編集") {
                                            editingMemoId = item.id
                                            editingMemoText = item.text
                                        }
                                        .buttonStyle(.bordered)
                                        Button("削除", role: .destructive) {
                                            model.deleteVideoMemo(video, memo: item)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }

                    Divider()

                    Text("質問")
                        .font(.headline)
                    HStack {
                        Button("CSV共有") {
                            let questions = model.questionsFor(video)
                            if questions.isEmpty {
                                showQuestionCsvEmptyState = true
                                return
                            }
                            showQuestionCsvEmptyState = false
                            questionCsvURL = makeQuestionCsvURL(
                                video: video,
                                questions: questions,
                            )
                        }
                        Spacer()
                    }
                    TextField("動画について質問", text: $questionText, axis: .vertical)
                        .lineLimit(4...12)
                        .textFieldStyle(.roundedBorder)
                    Button("質問を送信") {
                        Task {
                            await model.submitVideoQuestion(
                                video,
                                memo: memoText,
                                question: questionText,
                                playbackSeconds: playbackSeconds
                            )
                            questionText = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if model.questionsFor(video).isEmpty {
                        if showQuestionCsvEmptyState {
                            EmptyState("CSV共有対象の質問がありません")
                        } else {
                            Text("まだ質問はありません。")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(model.questionsFor(video)) { question in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("質問: \(question.questionText)")
                                if question.answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("回答待ち")
                                        .foregroundStyle(.orange)
                                } else {
                                    Text("回答: \(question.answerText)")
                                        .foregroundStyle(.green)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            } else {
                EmptyState("この動画に再生情報がありません。", systemImage: "video.slash")
            }
        }
        .onAppear {
            Task { await model.load() }
        }
        .navigationTitle(video.title)
        .sheet(
            isPresented: Binding(
                get: { memoCsvURL != nil },
                set: { if !$0 { memoCsvURL = nil } },
            ),
        ) {
            if let memoCsvURL {
                ActivityShareSheet(activityItems: [memoCsvURL])
            }
        }
        .sheet(
            isPresented: Binding(
                get: { questionCsvURL != nil },
                set: { if !$0 { questionCsvURL = nil } },
            ),
        ) {
            if let questionCsvURL {
                ActivityShareSheet(activityItems: [questionCsvURL])
            }
        }
        .ignoresSafeArea()
    }

    private func playbackTimeLabel(_ value: Double) -> String {
        let seconds = max(0, Int(value))
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }

    private func sendPlaybackCommand(_ action: VimeoPlaybackAction) {
        playbackCommandId += 1
        playbackCommand = VimeoPlaybackCommand(action: action, requestId: playbackCommandId)
    }

    private func makeMemoCsvURL(video: DistributedVideo, memos: [VimeoVideoMemo]) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("video-memos-\(video.id).csv")
        do {
            try VideoMemoCsvExporter.data(for: memos, video: video).write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func makeQuestionCsvURL(video: DistributedVideo, questions: [VideoQuestion]) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("video-questions-\(video.id).csv")
        do {
            try VideoQuestionCsvExporter.data(for: questions, video: video).write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

private struct DistributedVimeoVideoPlayerView: UIViewRepresentable {
    let videoId: String
    let initialPlaybackSeconds: Double
    let command: VimeoPlaybackCommand?
    let onPlaybackTimeChanged: (Double) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.userContentController.add(context.coordinator, name: "vimeoPlayerBridge")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        context.coordinator.webView = webView
        loadPlayerIfNeeded(webView: webView, in: context.coordinator)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.videoId != videoId {
            loadPlayerIfNeeded(webView: webView, in: coordinator)
        }
        guard let command,
              command.requestId != coordinator.lastCommandId else {
            return
        }
        coordinator.lastCommandId = command.requestId
        coordinator.execute(command)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "vimeoPlayerBridge")
        coordinator.webView = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            videoId: videoId,
            initialPlaybackSeconds: initialPlaybackSeconds,
            onPlaybackTimeChanged: onPlaybackTimeChanged
        )
    }

    private func loadPlayerIfNeeded(webView: WKWebView, in coordinator: Coordinator) {
        coordinator.videoId = videoId
        coordinator.lastCommandId = nil
        webView.loadHTMLString(
            vimeoPlayerHTML(videoId: videoId, initialSeconds: initialPlaybackSeconds),
            baseURL: URL(string: "https://player.vimeo.com")
        )
    }

    private func vimeoPlayerHTML(videoId: String, initialSeconds: Double) -> String {
        let sanitizedVideoId = videoId.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
        return """
            <!doctype html>
            <html>
            <head>
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">
            <style>
            html,body,#player { margin:0; width:100%; height:100%; background:#000; }
            </style>
            <script src=\"https://player.vimeo.com/api/player.js\"></script>
            </head>
            <body>
            <div id=\"player\"></div>
            <script>
            const initialSeconds = \(initialSeconds);
            const targetId = \(sanitizedVideoId);
            const bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.vimeoPlayerBridge;
            const sendMessage = function(payload) {
                if (!bridge) return;
                bridge.postMessage(payload);
            };
            const postError = function(message) {
                sendMessage({ type: 'error', message: message || '' });
            };
            const postTime = function(seconds) {
                sendMessage({ type: 'time', value: seconds || 0 });
            };

            const player = new Vimeo.Player('player', {
                id: targetId,
                autoplay: false,
                controls: true,
                dnt: true,
                playsinline: true,
                responsive: true
            });

            player.ready().then(function() {
                if (initialSeconds > 0) {
                    player.setCurrentTime(initialSeconds).catch(function() {});
                }
            }).catch(function(error) {
                postError(error && error.message ? error.message : 'Vimeoプレーヤーを準備できませんでした。');
            });

            window.vimeoReportTime = function() {
                player.getCurrentTime().then(function(value) {
                    postTime(value || 0);
                }).catch(function(error) {
                    postError(error && error.message ? error.message : '再生位置を取得できませんでした。');
                    postTime(0);
                });
            };
            window.vimeoSeekAndPlay = function(seconds) {
                player.setCurrentTime(seconds).then(function() {
                    return player.play();
                }).catch(function(error) {
                    postError(error && error.message ? error.message : '再生に失敗しました。');
                });
            };
            window.vimeoSeek = function(seconds) {
                player.setCurrentTime(seconds).catch(function(error) {
                    postError(error && error.message ? error.message : 'シークに失敗しました。');
                });
            };
            </script>
            </body>
            </html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var webView: WKWebView?
        var lastCommandId: Int?
        var videoId: String
        var initialPlaybackSeconds: Double
        let onPlaybackTimeChanged: (Double) -> Void
        var lastError: String?

        init(
            videoId: String,
            initialPlaybackSeconds: Double,
            onPlaybackTimeChanged: @escaping (Double) -> Void
        ) {
            self.videoId = videoId
            self.initialPlaybackSeconds = initialPlaybackSeconds
            self.onPlaybackTimeChanged = onPlaybackTimeChanged
            super.init()
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any] else { return }
            let type = body["type"] as? String
            switch type {
            case "time":
                let value = body["value"] as? Double
                onPlaybackTimeChanged(value ?? 0)
            case "error":
                if let message = body["message"] as? String {
                    lastError = message
                }
            default:
                break
            }
        }

        func execute(_ command: VimeoPlaybackCommand) {
            guard let webView else { return }
            switch command.action {
            case .reportCurrentTime:
                webView.evaluateJavaScript("window.vimeoReportTime();", completionHandler: nil)
            case .seek(let seconds):
                webView.evaluateJavaScript("window.vimeoSeek(\(seconds));", completionHandler: nil)
            case .seekAndPlay(let seconds):
                webView.evaluateJavaScript("window.vimeoSeekAndPlay(\(seconds));", completionHandler: nil)
            }
        }
    }
}

private enum VimeoPlaybackAction: Equatable {
    case reportCurrentTime
    case seek(Double)
    case seekAndPlay(Double)
}

private struct VimeoPlaybackCommand: Equatable {
    let action: VimeoPlaybackAction
    let requestId: Int
}

private func distributedVimeoVideoId(for video: DistributedVideo) -> String? {
    let candidates = [video.vimeoVideoId, video.vimeoUrl, video.videoUrl]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    for value in candidates {
        let numeric = value.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
        if !numeric.isEmpty { return numeric }
    }
    return nil
}

internal enum DistributedVideoPlayerSource: Equatable {
    case embedHtml(String)
    case url(String)
}

internal func distributedVideoSource(for video: DistributedVideo) -> DistributedVideoPlayerSource? {
    if !video.embedHtml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .embedHtml(video.embedHtml)
    }
    if !video.vimeoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .url(video.vimeoUrl)
    }
    if !video.videoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .url(video.videoUrl)
    }
    return nil
}

private struct DistributedVideoCell: View {
    let video: DistributedVideo

    var body: some View {
        HStack(spacing: 12) {
            if let thumbnail = URL(string: video.thumbnailUrl) {
                AsyncImage(url: thumbnail) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.secondary.opacity(0.2)
                }
                .frame(width: 96, height: 54)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 96, height: 54)
                    .overlay {
                        Image(systemName: "play.rectangle")
                            .foregroundStyle(.white.opacity(0.6))
                    }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(video.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if video.isMembersOnly {
                    Text("メンバー限定")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}
private struct FriendExchangeRootView: View {
    @ObservedObject var model: FriendExchangeFeatureModel
    @State private var editingContact: FriendContact?
    @State private var createsContact = false

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.contacts.isEmpty {
                    LoadingState()
                } else if model.contacts.isEmpty {
                    EmptyState(
                        "友達情報はまだありません",
                        systemImage: "person.crop.circle.badge.plus"
                    )
                } else {
                    List(model.contacts) { contact in
                        NavigationLink {
                            FriendContactDetailView(model: model, contact: contact)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.name).font(.headline)
                                if !contact.phoneNumber.isEmpty {
                                    Text(contact.phoneNumber).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button("編集") { editingContact = contact }
                        }
                    }
                }
            }
            .navigationTitle("友達情報・交流履歴帳")
            .toolbar {
                Button {
                    createsContact = true
                } label: {
                    Label("友達を追加", systemImage: "plus")
                }
            }
            .task { await model.loadContacts() }
            .sheet(isPresented: $createsContact) {
                FriendContactEditor(model: model, contact: nil)
            }
            .sheet(item: $editingContact) { contact in
                FriendContactEditor(model: model, contact: contact)
            }
            .alert(
                "エラー",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.clearError() } }
                )
            ) {
                Button("OK") { model.clearError() }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }
}

private struct FriendContactEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: FriendExchangeFeatureModel
    let contact: FriendContact?
    @State private var name: String
    @State private var postalCode: String
    @State private var prefecture: String
    @State private var city: String
    @State private var addressLine: String
    @State private var hasBirthDate: Bool
    @State private var birthDate: Date
    @State private var phoneNumber: String
    @State private var email: String

    init(model: FriendExchangeFeatureModel, contact: FriendContact?) {
        self.model = model
        self.contact = contact
        _name = State(initialValue: contact?.name ?? "")
        _postalCode = State(initialValue: contact?.postalCode ?? "")
        _prefecture = State(initialValue: contact?.prefecture ?? "")
        _city = State(initialValue: contact?.city ?? "")
        _addressLine = State(initialValue: contact?.addressLine ?? "")
        _hasBirthDate = State(initialValue: contact?.birthDate != nil)
        _birthDate = State(initialValue: contact?.birthDate ?? .now)
        _phoneNumber = State(initialValue: contact?.phoneNumber ?? "")
        _email = State(initialValue: contact?.email ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("名前（必須）", text: $name)
                TextField("郵便番号", text: $postalCode)
                TextField("都道府県", text: $prefecture)
                TextField("市区町村", text: $city)
                TextField("番地・建物名", text: $addressLine)
                Toggle("生年月日を登録", isOn: $hasBirthDate)
                if hasBirthDate {
                    DatePicker("生年月日", selection: $birthDate, displayedComponents: .date)
                }
                TextField("電話番号", text: $phoneNumber)
                    .keyboardType(.phonePad)
                TextField("メールアドレス", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            .navigationTitle(contact == nil ? "友達を追加" : "友達を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            let now = Date()
                            let value = FriendContact(
                                id: contact?.id ?? UUID(),
                                userId: contact?.userId ?? "guest-local",
                                name: name,
                                postalCode: postalCode,
                                prefecture: prefecture,
                                city: city,
                                addressLine: addressLine,
                                birthDate: hasBirthDate ? birthDate : nil,
                                phoneNumber: phoneNumber,
                                email: email,
                                createdAt: contact?.createdAt ?? now,
                                updatedAt: now
                            )
                            if await model.saveContact(value) { dismiss() }
                        }
                    }
                }
            }
        }
    }
}

private struct FriendContactDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject var model: FriendExchangeFeatureModel
    let contact: FriendContact
    @State private var createsHistory = false
    @State private var editingHistory: FriendInteractionHistory?
    @State private var confirmsDelete = false
    @State private var confirmsCall = false

    private var histories: [FriendInteractionHistory] {
        model.histories[contact.id] ?? []
    }

    var body: some View {
        List {
            Section("友達情報") {
                LabeledContent("名前", value: contact.name)
                if !contact.phoneNumber.isEmpty {
                    LabeledContent("電話", value: contact.phoneNumber)
                    Button("電話をかける") { confirmsCall = true }
                }
                if !contact.email.isEmpty { LabeledContent("メール", value: contact.email) }
                let address = [contact.postalCode, contact.prefecture, contact.city, contact.addressLine]
                    .filter { !$0.isEmpty }.joined(separator: " ")
                if !address.isEmpty { LabeledContent("住所", value: address) }
                if let birthDate = contact.birthDate {
                    LabeledContent("生年月日", value: birthDate.formatted(date: .numeric, time: .omitted))
                }
            }
            Section {
                Button("交流履歴を追加") { createsHistory = true }
                if histories.isEmpty {
                    Text("交流履歴はまだありません").foregroundStyle(.secondary)
                } else {
                    ForEach(histories) { history in
                        Button {
                            editingHistory = history
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(history.interactionDate.formatted(date: .abbreviated, time: .shortened))
                                Text(history.memo.isEmpty ? (history.isPhoneCall ? "電話" : "写真") : history.memo)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            } header: {
                Text("交流履歴")
            }
            Section {
                Button("この友達情報を削除", role: .destructive) { confirmsDelete = true }
            }
        }
        .navigationTitle(contact.name)
        .task { await model.loadHistories(friendId: contact.id) }
        .sheet(isPresented: $createsHistory) {
            FriendHistoryEditor(model: model, contact: contact, history: nil)
        }
        .sheet(item: $editingHistory) { history in
            FriendHistoryEditor(model: model, contact: contact, history: history)
        }
        .confirmationDialog("友達情報とすべての交流履歴を削除しますか？", isPresented: $confirmsDelete) {
            Button("削除", role: .destructive) {
                Task {
                    await model.deleteContact(contact)
                    dismiss()
                }
            }
        }
        .confirmationDialog("\(contact.phoneNumber) に電話をかけますか？", isPresented: $confirmsCall) {
            Button("電話をかける") {
                let digits = contact.phoneNumber.filter { $0.isNumber || $0 == "+" }
                if let url = URL(string: "tel:\(digits)") { openURL(url) }
            }
        }
    }
}

private struct FriendHistoryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: FriendExchangeFeatureModel
    let contact: FriendContact
    let history: FriendInteractionHistory?
    @State private var interactionDate: Date
    @State private var memo: String
    @State private var firstPhotoURL: String
    @State private var secondPhotoURL: String
    @State private var isPhoneCall: Bool
    @State private var phoneNumber: String
    @State private var confirmsDelete = false

    init(
        model: FriendExchangeFeatureModel,
        contact: FriendContact,
        history: FriendInteractionHistory?
    ) {
        self.model = model
        self.contact = contact
        self.history = history
        _interactionDate = State(initialValue: history?.interactionDate ?? .now)
        _memo = State(initialValue: history?.memo ?? "")
        _firstPhotoURL = State(initialValue: history?.photoUrls.first ?? "")
        _secondPhotoURL = State(initialValue: history?.photoUrls.dropFirst().first ?? "")
        _isPhoneCall = State(initialValue: history?.isPhoneCall ?? false)
        _phoneNumber = State(initialValue: history?.phoneNumber ?? contact.phoneNumber)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("交流日時", selection: $interactionDate)
                TextField("メモ", text: $memo, axis: .vertical)
                    .lineLimit(4...10)
                TextField("写真URL 1", text: $firstPhotoURL)
                    .textInputAutocapitalization(.never)
                TextField("写真URL 2", text: $secondPhotoURL)
                    .textInputAutocapitalization(.never)
                Toggle("電話での交流", isOn: $isPhoneCall)
                if isPhoneCall {
                    TextField("電話番号", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
                if history != nil {
                    Button("この履歴を削除", role: .destructive) { confirmsDelete = true }
                }

            }

            .navigationTitle(history == nil ? "交流履歴を追加" : "交流履歴を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            let now = Date()
                            let value = FriendInteractionHistory(
                                id: history?.id ?? UUID(),
                                friendId: contact.id,
                                interactionDate: interactionDate,
                                memo: memo,
                                photoUrls: [firstPhotoURL, secondPhotoURL].filter { !$0.isEmpty },
                                isPhoneCall: isPhoneCall,
                                phoneNumber: isPhoneCall ? phoneNumber : "",
                                createdAt: history?.createdAt ?? now,
                                updatedAt: now
                            )
                            if await model.saveHistory(value) { dismiss() }
                        }
                    }
                }
            }
            .confirmationDialog("この交流履歴を削除しますか？", isPresented: $confirmsDelete) {
                Button("削除", role: .destructive) {
                    guard let history else { return }
                    Task {
                        await model.deleteHistory(history)
                        dismiss()
                    }
                }
            }
        }
    }

}
