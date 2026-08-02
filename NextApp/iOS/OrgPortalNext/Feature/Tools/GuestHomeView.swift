import DesignSystem
import DataLayer
import SwiftUI
import UniformTypeIdentifiers

public enum GuestHomeTool: String, CaseIterable, Identifiable, Sendable {
    case schedule
    case diary
    case denomination
    case meetingMinutes
    case favorites
    case youTubeSearch
    case personalVideos
    case manual

    public var id: String { rawValue }

    public static let ordered: [GuestHomeTool] = [
        .schedule,
        .diary,
        .denomination,
        .meetingMinutes,
        .favorites,
        .youTubeSearch,
        .personalVideos,
        .manual,
    ]

    public var isAvailable: Bool {
        true
    }

    var title: LocalizedStringKey {
        switch self {
        case .schedule: "home.schedule.title"
        case .diary: "home.diary.title"
        case .denomination: "home.denomination.title"
        case .meetingMinutes: "home.meeting_minutes.title"
        case .favorites: "お気に入り"
        case .youTubeSearch: "YouTube検索・登録"
        case .personalVideos: "YouTube動画メモ"
        case .manual: "使い方マニュアル"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .schedule: "home.schedule.subtitle"
        case .diary: "home.diary.subtitle"
        case .denomination: "home.denomination.subtitle"
        case .meetingMinutes: "home.meeting_minutes.subtitle"
        case .favorites: "よく見るWebページを自分専用に保存します。"
        case .youTubeSearch: "検索結果から開いた動画をお気に入りに登録できます。"
        case .personalVideos: "タイトル・URL・再生位置メモを端末内で管理します。"
        case .manual: "アプリの主要機能をすばやく確認できます。"
        }
    }

    var systemImage: String {
        switch self {
        case .schedule: "calendar"
        case .diary: "book.closed"
        case .denomination: "yensign.circle"
        case .meetingMinutes: "mic"
        case .favorites: "bookmark"
        case .youTubeSearch: "magnifyingglass"
        case .personalVideos: "play.rectangle"
        case .manual: "book.closed"
        }
    }
}

public struct GuestHomeView: View {
    @ObservedObject private var scheduleModel: ScheduleFeatureModel
    @ObservedObject private var diaryModel: DiaryFeatureModel
    @ObservedObject private var cashDistributionModel: CashDistributionFeatureModel
    @ObservedObject private var meetingMinutesModel: MeetingMinutesFeatureModel
    @ObservedObject private var favoriteBookmarkModel: FavoriteBookmarkFeatureModel
    @ObservedObject private var personalVideoModel: PersonalVideoFeatureModel
    @ObservedObject private var appBackupModel: AppBackupFeatureModel
    @State private var isShowingTodaySchedule = false
    @State private var isShowingDiary = false
    @State private var isShowingDenomination = false
    @State private var isShowingMeetingMinutes = false
    @State private var isShowingFavorites = false
    @State private var isShowingPersonalVideos = false
    @State private var isShowingManual = false
    @State private var isShowingYoutubeSearch = false
    @State private var isShowingAppBackup = false

    public init(
        scheduleModel: ScheduleFeatureModel,
        diaryModel: DiaryFeatureModel,
        cashDistributionModel: CashDistributionFeatureModel,
        meetingMinutesModel: MeetingMinutesFeatureModel,
        favoriteBookmarkModel: FavoriteBookmarkFeatureModel,
        personalVideoModel: PersonalVideoFeatureModel,
        appBackupModel: AppBackupFeatureModel
    ) {
        self.scheduleModel = scheduleModel
        self.diaryModel = diaryModel
        self.cashDistributionModel = cashDistributionModel
        self.meetingMinutesModel = meetingMinutesModel
        self.favoriteBookmarkModel = favoriteBookmarkModel
        self.personalVideoModel = personalVideoModel
        self.appBackupModel = appBackupModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.contentSpacing) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("home.guest.title")
                            .font(.title2.bold())
                        Spacer()
                        StatusBadge("home.guest.badge", systemImage: "person.crop.circle")
                    }
                    Text("home.guest.message")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(GuestHomeTool.ordered) { tool in
                        if tool == .schedule {
                            Button {
                                isShowingTodaySchedule = true
                            } label: {
                                FeatureCard(
                                    tool.title,
                                    subtitle: tool.subtitle,
                                    systemImage: tool.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("home.schedule.accessibility_hint")
                        } else if tool == .diary {
                            Button {
                                isShowingDiary = true
                            } label: {
                                FeatureCard(
                                    tool.title,
                                    subtitle: tool.subtitle,
                                    systemImage: tool.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("home.diary.accessibility_hint")
                        } else if tool == .denomination {
                            Button {
                                isShowingDenomination = true
                            } label: {
                                FeatureCard(
                                    tool.title,
                                    subtitle: tool.subtitle,
                                    systemImage: tool.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("home.denomination.accessibility_hint")
                        } else if tool == .meetingMinutes {
                            Button {
                                isShowingMeetingMinutes = true
                            } label: {
                                FeatureCard(
                                    tool.title,
                                    subtitle: tool.subtitle,
                                    systemImage: tool.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                        } else if tool == .favorites {
                            Button {
                                isShowingFavorites = true
                            } label: {
                                FeatureCard(
                                    tool.title,
                                    subtitle: tool.subtitle,
                                    systemImage: tool.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                        } else if tool == .youTubeSearch {
                            Button {
                                isShowingYoutubeSearch = true
                            } label: {
                                FeatureCard(
                                    tool.title,
                                    subtitle: tool.subtitle,
                                    systemImage: tool.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                        } else if tool == .personalVideos {
                            Button {
                                isShowingPersonalVideos = true
                            } label: {
                                FeatureCard(
                                    tool.title,
                                    subtitle: tool.subtitle,
                                    systemImage: tool.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                        } else if tool == .manual {
                            Button {
                                isShowingManual = true
                            } label: {
                                FeatureCard(
                                    tool.title,
                                    subtitle: tool.subtitle,
                                    systemImage: tool.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        isShowingAppBackup = true
                    } label: {
                        FeatureCard(
                            "アプリ削除前のバックアップ",
                            subtitle: "予定・日記と写真・金種計算・会議録音・SNSリンク・お気に入り・友達情報・交流履歴・個人動画をまとめて保存します。",
                            systemImage: "externaldrive.badge.timemachine"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationTitle("tab.home")
        }
        .sheet(isPresented: $isShowingTodaySchedule) {
            TodayScheduleView(model: scheduleModel)
        }
        .sheet(isPresented: $isShowingDiary) {
            DiaryRootView(model: diaryModel)
        }
        .sheet(isPresented: $isShowingDenomination) {
            DenominationToolView(model: cashDistributionModel)
        }
        .sheet(isPresented: $isShowingMeetingMinutes) {
            MeetingMinutesRootView(model: meetingMinutesModel)
        }
        .sheet(isPresented: $isShowingFavorites) {
            FavoriteBookmarksView(model: favoriteBookmarkModel)
        }
        .sheet(isPresented: $isShowingPersonalVideos) {
            PersonalVideosView(model: personalVideoModel)
        }
        .sheet(isPresented: $isShowingManual) {
            ManualListView()
        }
        .sheet(isPresented: $isShowingYoutubeSearch) {
            YoutubeSearchView()
        }
        .sheet(isPresented: $isShowingAppBackup) {
            AppBackupView(model: appBackupModel)
        }
    }
}

private struct YoutubeSearchView: View {
    @State private var keyword = ""
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section("YouTube検索") {
                    TextField("検索ワード", text: $keyword)
                    Button {
                        openYouTubeSearch()
                    } label: {
                        Label("YouTubeで検索", systemImage: "magnifyingglass")
                    }
                    .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("使い方") {
                    Text("検索結果から開いた動画URLを『お気に入り』画面で保存できます。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("YouTube検索・登録")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func openYouTubeSearch() {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)") else {
            return
        }
        openURL(url)
    }
}

public struct AppBackupDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.json] }
    public var data: Data

    public init(data: Data = Data()) {
        self.data = data
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
public final class AppBackupFeatureModel: ObservableObject {
    @Published public private(set) var isWorking = false
    @Published public var message: String?
    @Published public var exportDocument = AppBackupDocument()
    @Published public var showsExporter = false
    @Published public var showsImporter = false
    @Published public private(set) var skippedMeetingMinutes = 0

    private let service: AppBackupService

    public init(service: AppBackupService) {
        self.service = service
    }

    public func prepareExport() {
        isWorking = true
        message = nil
        Task {
            do {
                let result = try await service.exportData()
                exportDocument = AppBackupDocument(data: result.data)
                skippedMeetingMinutes = result.skippedMeetingMinutes
                isWorking = false
                showsExporter = true
            } catch {
                isWorking = false
                message = error.localizedDescription
            }
        }
    }

    public func importBackup(from url: URL) {
        isWorking = true
        message = nil
        Task {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let summary = try await service.importData(Data(contentsOf: url))
                isWorking = false
                message = "復元が完了しました（合計\(summary.total)件）。"
            } catch {
                isWorking = false
                message = error.localizedDescription
            }
        }
    }
}

private struct AppBackupView: View {
    @ObservedObject var model: AppBackupFeatureModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("バックアップ対象") {
                    Text("予定、日記・写真、金種計算、会議録音・議事録、SNS独自リンク、お気に入りURL/メモ/カテゴリ、個人動画、友達情報、交流履歴")
                    Text("会員情報・コミュニティ・お知らせはFirebaseに保存されているため、このファイルには含みません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("アプリを削除する前に") {
                    Button {
                        model.prepareExport()
                    } label: {
                        Label("バックアップを書き出す", systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.isWorking)

                    Button {
                        model.showsImporter = true
                    } label: {
                        Label("バックアップを読み込む", systemImage: "square.and.arrow.down")
                    }
                    .disabled(model.isWorking)
                }
                if model.isWorking {
                    Section {
                        ProgressView("処理しています…")
                    }
                }
                if let message = model.message {
                    Section {
                        Text(message)
                    }
                }
            }
            .navigationTitle("アプリ削除前のバックアップ")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .fileExporter(
            isPresented: $model.showsExporter,
            document: model.exportDocument,
            contentType: .json,
            defaultFilename: "OrgPortalBackup"
        ) { result in
            if case let .failure(error) = result {
                model.message = error.localizedDescription
            } else {
                if model.skippedMeetingMinutes > 0 {
                    model.message = "バックアップを書き出しました。録音ファイルが見つからない議事録\(model.skippedMeetingMinutes)件は除外しました。その他のデータは保存されています。"
                } else {
                    model.message = "バックアップを書き出しました。アプリを削除する前に安全な場所へ保管してください。"
                }
            }
        }
        .fileImporter(
            isPresented: $model.showsImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                if let url = urls.first { model.importBackup(from: url) }
            case let .failure(error):
                model.message = error.localizedDescription
            }
        }
    }
}
