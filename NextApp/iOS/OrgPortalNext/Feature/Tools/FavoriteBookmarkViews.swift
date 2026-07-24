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
                        onSave: { title, url, note, category in
                            let didSave = await model.save(
                                existing: existing,
                                title: title,
                                url: url,
                                note: note,
                                category: category
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
                    Text(favorite.category)
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
    let onSave: (String, String, String, String) async -> Void
    let onDelete: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var url: String
    @State private var note: String
    @State private var category: String
    @State private var isSaving = false
    @State private var confirmsDeletion = false

    init(
        existing: FavoriteBookmark?,
        onSave: @escaping (String, String, String, String) async -> Void,
        onDelete: (() async -> Void)?
    ) {
        self.existing = existing
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: existing?.title ?? "")
        _url = State(initialValue: existing?.url ?? "https://")
        _note = State(initialValue: existing?.note ?? "")
        _category = State(initialValue: existing?.category ?? FavoriteBookmark.uncategorized)
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
                    TextField("カテゴリ", text: $category)
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
                            await onSave(title, url, note, category)
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
