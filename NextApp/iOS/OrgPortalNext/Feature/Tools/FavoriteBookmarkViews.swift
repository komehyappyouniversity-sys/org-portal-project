import DesignSystem
import Model
import SwiftUI
import UIKit
import UniformTypeIdentifiers

public struct FavoriteBookmarksView: View {
    private enum ActiveSheet: Identifiable {
        case editor(FavoriteBookmark?)
        case share(FavoriteBookmark)

        var id: String {
            switch self {
            case let .editor(value):
                "editor-\(value?.id.uuidString ?? "new")"
            case let .share(value):
                "share-\(value.id.uuidString)"
            }
        }
    }

    @ObservedObject private var model: FavoriteBookmarkFeatureModel
    @State private var activeSheet: ActiveSheet?
    @State private var exportDocument = FavoriteBookmarkBackupDocument()
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var backupMessage: String?

    public init(model: FavoriteBookmarkFeatureModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.isLoading, model.favorites.isEmpty {
                    LoadingState()
                } else if let error = model.errorMessage, model.favorites.isEmpty {
                    ErrorState(message: error) {
                        Task { await model.load() }
                    }
                } else if model.favorites.isEmpty {
                    EmptyState("お気に入りはまだありません", systemImage: "bookmark")
                } else {
                    List {
                        ForEach(model.favorites) { favorite in
                            FavoriteBookmarkRow(
                                favorite: favorite,
                                onOpen: { open(favorite) },
                                onEdit: { activeSheet = .editor(favorite) },
                                onShare: { activeSheet = .share(favorite) }
                            )
                        }
                        .onDelete { offsets in
                            let values = offsets.map { model.favorites[$0] }
                            Task {
                                for value in values {
                                    await model.delete(value)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("お気に入り")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("バックアップ", systemImage: "externaldrive") {
                        Button("バックアップを書き出す", systemImage: "square.and.arrow.up") {
                            Task { await prepareExport() }
                        }
                        .disabled(model.favorites.isEmpty)
                        Button("バックアップを読み込む", systemImage: "square.and.arrow.down") {
                            isImporting = true
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activeSheet = .editor(nil)
                    } label: {
                        Label("お気に入りを追加", systemImage: "plus")
                    }
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "お気に入りバックアップ"
            ) { result in
                if case .failure = result {
                    backupMessage = "バックアップを書き出せませんでした。"
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json]
            ) { result in
                Task { await importBackup(result) }
            }
            .alert(
                backupMessage ?? "",
                isPresented: Binding(
                    get: { backupMessage != nil },
                    set: { if !$0 { backupMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            }
            .task { await model.load() }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case let .editor(existing):
                    FavoriteBookmarkEditor(
                        existing: existing,
                        onSave: {
                            title,
                            url,
                            note,
                            category,
                            secondaryCategory,
                            tertiaryCategory in
                            let didSave = await model.save(
                                existing: existing,
                                title: title,
                                url: url,
                                note: note,
                                category: category,
                                secondaryCategory: secondaryCategory,
                                tertiaryCategory: tertiaryCategory
                            )
                            if didSave {
                                activeSheet = nil
                            }
                        },
                        onDelete: existing.map { value in
                            {
                                await model.delete(value)
                                activeSheet = nil
                            }
                        }
                    )
                case let .share(favorite):
                    ActivityShareSheet(
                        activityItems: [favorite.title, favorite.url, favorite.note]
                    )
                }
            }
            .alert(
                "お知らせ",
                isPresented: Binding(
                    get: { model.notice != nil },
                    set: { if !$0 { model.clearNotice() } }
                )
            ) {
                Button("閉じる") { model.clearNotice() }
            } message: {
                Text(model.notice ?? "")
            }
            .alert(
                "処理できませんでした",
                isPresented: Binding(
                    get: { model.errorMessage != nil && !model.favorites.isEmpty },
                    set: { if !$0 { model.clearError() } }
                )
            ) {
                Button("閉じる") { model.clearError() }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }

    private func open(_ favorite: FavoriteBookmark) {
        guard let url = URL(string: favorite.url) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func prepareExport() async {
        do {
            exportDocument = FavoriteBookmarkBackupDocument(
                data: try await model.exportBackup()
            )
            isExporting = true
        } catch {
            backupMessage = "バックアップを書き出せませんでした。"
        }
    }

    private func importBackup(_ result: Result<URL, Error>) async {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            let count = try await model.importBackup(Data(contentsOf: url))
            backupMessage = "\(count)件のお気に入りを復元しました。"
        } catch {
            backupMessage = "バックアップを読み込めませんでした。"
        }
    }
}

public struct PersonalVideosView: View {
    @ObservedObject private var model: PersonalVideoFeatureModel
    @State private var showsEditor = false
    @State private var editingVideo: PersonalVideo?

    public init(model: PersonalVideoFeatureModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.isLoading, model.videos.isEmpty {
                    LoadingState()
                } else if let error = model.errorMessage, model.videos.isEmpty {
                    ErrorState(message: error) { Task { await model.loadVideos() } }
                } else if model.videos.isEmpty {
                    EmptyState(
                        title: "登録動画はまだありません",
                        message: "YouTube動画を登録すると、再生位置や時間メモを残せます。",
                        systemImage: "play.rectangle"
                    )
                } else {
                    List {
                        ForEach(model.videos) { video in
                            NavigationLink {
                                PersonalVideoDetailView(model: model, video: video)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(video.title).font(.headline)
                                    if !video.categoryPath.isEmpty {
                                        Text(video.categoryPath)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if video.savedPositionSeconds > 0 {
                                        Label(
                                            PersonalVideoTime.format(video.savedPositionSeconds),
                                            systemImage: "bookmark.fill"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .swipeActions {
                                Button("削除", role: .destructive) {
                                    Task { await model.deleteVideo(video) }
                                }
                                Button("編集") {
                                    editingVideo = video
                                    showsEditor = true
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("動画メモ")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingVideo = nil
                        showsEditor = true
                    } label: {
                        Label("動画を追加", systemImage: "plus")
                    }
                }
            }
            .task { await model.loadVideos() }
            .refreshable { await model.loadVideos() }
            .sheet(isPresented: $showsEditor) {
                PersonalVideoEditorView(model: model, video: editingVideo)
            }
            .alert("お知らせ", isPresented: Binding(
                get: { model.notice != nil },
                set: { if !$0 { model.clearNotice() } }
            )) {
                Button("OK") { model.clearNotice() }
            } message: {
                Text(model.notice ?? "")
            }
            .alert("エラー", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.clearError() } }
            )) {
                Button("OK") { model.clearError() }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }
}

private struct PersonalVideoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PersonalVideoFeatureModel
    let video: PersonalVideo?

    @State private var title: String
    @State private var urlOrId: String
    @State private var note: String
    @State private var savedTime: String
    @State private var category: String
    @State private var secondaryCategory: String
    @State private var tertiaryCategory: String
    @State private var localError: String?
    @State private var isSaving = false

    init(model: PersonalVideoFeatureModel, video: PersonalVideo?) {
        self.model = model
        self.video = video
        _title = State(initialValue: video?.title ?? "")
        _urlOrId = State(initialValue: video?.originalURL ?? "")
        _note = State(initialValue: video?.note ?? "")
        _savedTime = State(initialValue: PersonalVideoTime.format(video?.savedPositionSeconds ?? 0))
        _category = State(initialValue: video?.category ?? "")
        _secondaryCategory = State(initialValue: video?.secondaryCategory ?? "")
        _tertiaryCategory = State(initialValue: video?.tertiaryCategory ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("動画") {
                    TextField("タイトル", text: $title)
                    TextField("YouTube URLまたは動画ID", text: $urlOrId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("保存位置（例 12:34）", text: $savedTime)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("動画全体のメモ", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("3段階カテゴリ") {
                    TextField("第1カテゴリ", text: $category)
                        .onChange(of: category) { _, value in
                            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                secondaryCategory = ""
                                tertiaryCategory = ""
                            }
                        }
                    TextField("第2カテゴリ", text: $secondaryCategory)
                        .disabled(category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .onChange(of: secondaryCategory) { _, value in
                            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                tertiaryCategory = ""
                            }
                        }
                    TextField("第3カテゴリ", text: $tertiaryCategory)
                        .disabled(secondaryCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(video == nil ? "動画を追加" : "動画を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(isSaving)
                }
            }
            .alert("入力を確認してください", isPresented: Binding(
                get: { localError != nil }, set: { if !$0 { localError = nil } }
            )) {
                Button("OK") { localError = nil }
            } message: {
                Text(localError ?? "")
            }
        }
    }

    private func save() {
        guard let seconds = PersonalVideoTime.parse(savedTime) else {
            localError = "保存位置は 12:34 または 1:02:03 の形式で入力してください。"
            return
        }
        isSaving = true
        Task {
            let succeeded = await model.saveVideo(
                existing: video,
                title: title,
                urlOrId: urlOrId,
                note: note,
                savedPositionSeconds: seconds,
                category: category,
                secondaryCategory: secondaryCategory,
                tertiaryCategory: tertiaryCategory
            )
            isSaving = false
            if succeeded { dismiss() }
        }
    }
}

private struct PersonalVideoDetailView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var model: PersonalVideoFeatureModel
    let video: PersonalVideo
    @State private var memoText = ""
    @State private var memoTime = "0:00"

    var body: some View {
        List {
            Section("動画") {
                Text(video.title).font(.headline)
                if !video.categoryPath.isEmpty {
                    LabeledContent("カテゴリ", value: video.categoryPath)
                }
                if !video.note.isEmpty { Text(video.note) }
                Button("YouTubeで開く") {
                    openURL(video.canonicalURL)
                }
                if video.savedPositionSeconds > 0 {
                    Button("保存位置 \(PersonalVideoTime.format(video.savedPositionSeconds)) から再生") {
                        openURL(video.timestampedURL)
                    }
                }
            }
            Section("時間メモを追加") {
                TextField("時刻（例 4:11）", text: $memoTime)
                    .keyboardType(.numbersAndPunctuation)
                TextField("この時点のメモ", text: $memoText, axis: .vertical)
                Button("メモを保存") {
                    guard let seconds = PersonalVideoTime.parse(memoTime) else {
                        model.errorMessage = "時刻は 4:11 または 1:02:03 の形式で入力してください。"
                        return
                    }
                    Task {
                        if await model.saveMemo(videoId: video.id, text: memoText, positionSeconds: seconds) {
                            memoText = ""
                        }
                    }
                }
            }
            Section("保存済み時間メモ") {
                let memos = model.memosByVideo[video.id] ?? []
                if memos.isEmpty {
                    Text("時間メモはまだありません。").foregroundStyle(.secondary)
                } else {
                    ForEach(memos) { memo in
                        VStack(alignment: .leading, spacing: 6) {
                            Button(PersonalVideoTime.format(memo.positionSeconds)) {
                                if let url = URL(string: "https://www.youtube.com/watch?v=\(video.providerVideoId)&t=\(memo.positionSeconds)s") {
                                    openURL(url)
                                }
                            }
                            Text(memo.text)
                        }
                        .swipeActions {
                            Button("削除", role: .destructive) {
                                Task { await model.deleteMemo(memo) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("動画メモ")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadMemos(videoId: video.id) }
    }
}

private enum PersonalVideoTime {
    static func format(_ seconds: Int) -> String {
        let value = max(0, seconds)
        let hours = value / 3_600
        let minutes = value % 3_600 / 60
        let remaining = value % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remaining)
            : String(format: "%d:%02d", minutes, remaining)
    }

    static func parse(_ text: String) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard (1...3).contains(parts.count), parts.allSatisfy({ Int($0) != nil }) else { return nil }
        let values = parts.compactMap { Int($0) }
        guard values.allSatisfy({ $0 >= 0 }) else { return nil }
        switch values.count {
        case 1: return values[0]
        case 2 where values[1] < 60: return values[0] * 60 + values[1]
        case 3 where values[1] < 60 && values[2] < 60:
            return values[0] * 3_600 + values[1] * 60 + values[2]
        default: return nil
        }
    }
}

private struct FavoriteBookmarkRow: View {
    let favorite: FavoriteBookmark
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(favorite.title)
                        .font(.headline)
                    Text(favorite.categoryPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("編集", systemImage: "pencil", action: onEdit)
                    Button("共有", systemImage: "square.and.arrow.up", action: onShare)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("\(favorite.title)の操作")
            }
            Text(favorite.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if !favorite.note.isEmpty {
                Text(favorite.note)
                    .font(.subheadline)
                    .lineLimit(3)
            }
            Button("リンクを開く", action: onOpen)
        }
        .padding(.vertical, 4)
    }
}

private struct FavoriteBookmarkEditor: View {
    let existing: FavoriteBookmark?
    let onSave: (String, String, String, String, String, String) async -> Void
    let onDelete: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var url: String
    @State private var note: String
    @State private var category: String
    @State private var secondaryCategory: String
    @State private var tertiaryCategory: String
    @State private var isSaving = false
    @State private var confirmsDeletion = false

    init(
        existing: FavoriteBookmark?,
        onSave: @escaping (String, String, String, String, String, String) async -> Void,
        onDelete: (() async -> Void)?
    ) {
        self.existing = existing
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: existing?.title ?? "")
        _url = State(initialValue: existing?.url ?? "https://")
        _note = State(initialValue: existing?.note ?? "")
        _category = State(initialValue: existing?.category ?? FavoriteBookmark.uncategorized)
        _secondaryCategory = State(initialValue: existing?.secondaryCategory ?? "")
        _tertiaryCategory = State(initialValue: existing?.tertiaryCategory ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("リンク情報") {
                    TextField("タイトル（必須）", text: $title)
                    TextField("URL（必須）", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("大分類", text: $category)
                    TextField("中分類", text: $secondaryCategory)
                    TextField("小分類", text: $tertiaryCategory)
                        .disabled(secondaryCategory.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty)
                    TextField("メモ", text: $note, axis: .vertical)
                        .lineLimit(4...8)
                }
                if onDelete != nil {
                    Section {
                        Button("このお気に入りを削除", role: .destructive) {
                            confirmsDeletion = true
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "お気に入りを追加" : "お気に入りを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        isSaving = true
                        Task {
                            await onSave(
                                title,
                                url,
                                note,
                                category,
                                secondaryCategory,
                                tertiaryCategory
                            )
                            isSaving = false
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .confirmationDialog(
                "このお気に入りを削除しますか？",
                isPresented: $confirmsDeletion,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    if let onDelete {
                        Task { await onDelete() }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
}
