import DesignSystem
import Model
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

public struct DiaryRootView: View {
    @ObservedObject private var model: DiaryFeatureModel

    public init(model: DiaryFeatureModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            DiaryListView(model: model)
        }
    }
}

private struct DiaryListView: View {
    @ObservedObject var model: DiaryFeatureModel
    @State private var editorMode: DiaryEditorMode?
    @State private var exportDocument = DiaryBackupDocument()
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var backupMessage: String?

    var body: some View {
        Group {
            if model.isLoading {
                LoadingState()
            } else if let error = model.errorMessage {
                ErrorState(message: error) {
                    Task { await model.load() }
                }
            } else if model.diaries.isEmpty {
                EmptyState("diary.empty", systemImage: "book.closed")
            } else {
                List(model.diaries) { diary in
                    NavigationLink {
                        DiaryDetailView(model: model, diary: diary)
                    } label: {
                        DiaryRow(model: model, diary: diary)
                    }
                }
            }
        }
        .navigationTitle("screen.diary.list")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu("diary.backup", systemImage: "externaldrive") {
                    Button("diary.backup.export", systemImage: "square.and.arrow.up") {
                        Task { await prepareExport() }
                    }
                    .disabled(model.diaries.isEmpty)
                    Button("diary.backup.import", systemImage: "square.and.arrow.down") {
                        isImporting = true
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("action.add", systemImage: "plus") {
                    editorMode = .new
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            DiaryEditorView(model: model, mode: mode)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "日記バックアップ"
        ) { result in
            if case .failure = result {
                backupMessage = String(localized: "diary.backup.export_failed")
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
        .refreshable { await model.load() }
    }

    private func prepareExport() async {
        do {
            exportDocument = DiaryBackupDocument(data: try await model.exportBackup())
            isExporting = true
        } catch {
            backupMessage = String(localized: "diary.backup.export_failed")
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
            backupMessage = String(
                format: String(localized: "diary.backup.import_succeeded"),
                count
            )
        } catch {
            backupMessage = String(localized: "diary.backup.import_failed")
        }
    }
}

private struct DiaryRow: View {
    let model: DiaryFeatureModel
    let diary: Diary

    var body: some View {
        HStack(spacing: 12) {
            if let reference = diary.photoUrls.first {
                DiaryPhotoThumbnail(model: model, reference: reference)
                    .frame(width: 64, height: 64)
            } else {
                Image(systemName: "book.closed")
                    .font(.title2)
                    .foregroundStyle(DesignTokens.brandGreen)
                    .frame(width: 64, height: 64)
                    .background(.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(diary.title).font(.headline)
                Text(diary.createdAt, format: .dateTime.year().month().day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(LocalizedStringKey(diary.mood.localizationKey))
                    .font(.caption)
            }
        }
        .frame(minHeight: DesignTokens.minimumTapHeight)
    }
}

public struct DiaryDetailView: View {
    @ObservedObject private var model: DiaryFeatureModel
    @Environment(\.dismiss) private var dismiss
    @State private var editorMode: DiaryEditorMode?
    @State private var showDeleteConfirmation = false
    @State private var gallerySelection: DiaryGallerySelection?
    private let diary: Diary

    public init(model: DiaryFeatureModel, diary: Diary) {
        self.model = model
        self.diary = diary
    }

    public var body: some View {
        List {
            LabeledContent("diary.date") {
                Text(diary.createdAt, format: .dateTime.year().month().day())
            }
            LabeledContent("diary.mood") {
                Text(LocalizedStringKey(diary.mood.localizationKey))
            }
            if !diary.body.isEmpty {
                Section("diary.body") {
                    Text(diary.body)
                        .textSelection(.enabled)
                }
            }
            if !diary.photoUrls.isEmpty {
                Section("diary.photos") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(Array(diary.photoUrls.enumerated()), id: \.element) {
                                index, reference in
                                Button {
                                    showGallery(initialIndex: index)
                                } label: {
                                    DiaryPhotoThumbnail(model: model, reference: reference)
                                        .frame(width: 150, height: 150)
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("diary.photo.enlarge")
                            }
                        }
                    }
                }
            }
            Button("action.delete", systemImage: "trash", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
        .navigationTitle(diary.title)
        .toolbar {
            Button("action.edit") {
                editorMode = .edit(diary)
            }
        }
        .sheet(item: $editorMode) { mode in
            DiaryEditorView(model: model, mode: mode)
        }
        .fullScreenCover(item: $gallerySelection) { selection in
            DiaryPhotoGallery(selection: selection)
        }
        .alert("diary.delete.title", isPresented: $showDeleteConfirmation) {
            Button("action.cancel", role: .cancel) {}
            Button("action.delete", role: .destructive) {
                Task {
                    await model.delete(diary)
                    dismiss()
                }
            }
        } message: {
            Text("diary.delete.message")
        }
    }

    private func showGallery(initialIndex: Int) {
        let photos = diary.photoUrls.compactMap { try? model.photoData(reference: $0) }
        guard !photos.isEmpty else { return }
        gallerySelection = DiaryGallerySelection(
            photos: photos,
            initialIndex: min(initialIndex, photos.count - 1)
        )
    }
}

public enum DiaryEditorMode: Identifiable {
    case new
    case edit(Diary)

    public var id: String {
        switch self {
        case .new: "new"
        case .edit(let diary): diary.id.uuidString
        }
    }
}

private struct DiaryEditorView: View {
    @ObservedObject var model: DiaryFeatureModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Diary
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var newPhotos: [Data] = []
    @State private var removedReferences: Set<String> = []
    @State private var validationMessage: LocalizedStringKey?
    private let titleKey: LocalizedStringKey

    init(model: DiaryFeatureModel, mode: DiaryEditorMode) {
        self.model = model
        switch mode {
        case .new:
            _draft = State(
                initialValue: Diary(userId: "guest", title: "")
            )
            titleKey = "screen.diary.new"
        case .edit(let diary):
            _draft = State(initialValue: diary)
            titleKey = "screen.diary.edit"
        }
    }

    private var visibleExistingReferences: [String] {
        draft.photoUrls.filter { !removedReferences.contains($0) }
    }

    private var remainingPhotoCount: Int {
        max(
            0,
            Diary.maximumPhotoCount - visibleExistingReferences.count - newPhotos.count
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("diary.title", text: $draft.title)
                TextField("diary.body", text: $draft.body, axis: .vertical)
                    .lineLimit(5...14)
                Picker("diary.mood", selection: $draft.mood) {
                    ForEach(DiaryMood.allCases, id: \.self) { mood in
                        Text(LocalizedStringKey(mood.localizationKey)).tag(mood)
                    }
                }

                Section("diary.photos") {
                    if !visibleExistingReferences.isEmpty || !newPhotos.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 12) {
                                ForEach(visibleExistingReferences, id: \.self) { reference in
                                    removableThumbnail(
                                        DiaryPhotoThumbnail(
                                            model: model,
                                            reference: reference
                                        )
                                    ) {
                                        removedReferences.insert(reference)
                                    }
                                }
                                ForEach(Array(newPhotos.enumerated()), id: \.offset) {
                                    index, data in
                                    removableThumbnail(
                                        DiaryDataThumbnail(data: data)
                                    ) {
                                        newPhotos.remove(at: index)
                                    }
                                }
                            }
                        }
                    }
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: remainingPhotoCount,
                        matching: .images
                    ) {
                        Label(
                            "diary.photo.select",
                            systemImage: "photo.badge.plus"
                        )
                    }
                    .disabled(remainingPhotoCount == 0)
                    Text(
                        String(
                            format: String(localized: "diary.photo.remaining"),
                            remainingPhotoCount
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let validationMessage {
                    Text(validationMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle(titleKey)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") {
                        Task { await save() }
                    }
                }
            }
            .onChange(of: pickerItems) { _, items in
                Task { await loadPickerItems(items) }
            }
        }
    }

    private func removableThumbnail<Content: View>(
        _ content: Content,
        onRemove: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            content.frame(width: 120, height: 120)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.65))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("action.delete")
        }
    }

    private func loadPickerItems(_ items: [PhotosPickerItem]) async {
        for item in items.prefix(remainingPhotoCount) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let compressed = DiaryPhotoProcessor.compressedJPEGData(from: data) else {
                continue
            }
            newPhotos.append(compressed)
        }
        pickerItems = []
    }

    private func save() async {
        do {
            try await model.save(
                draft,
                newPhotoData: newPhotos,
                removedPhotoReferences: removedReferences
            )
            dismiss()
        } catch let error as DiaryValidationError {
            validationMessage = LocalizedStringKey(error.localizationKey)
        } catch {
            validationMessage = "state.error"
        }
    }
}

private struct DiaryPhotoThumbnail: View {
    let model: DiaryFeatureModel
    let reference: String
    @State private var data: Data?

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .clipped()
        .task(id: reference) {
            data = try? model.photoData(reference: reference)
        }
    }
}

private struct DiaryDataThumbnail: View {
    let data: Data

    var body: some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .clipped()
    }
}

public struct DiaryGallerySelection: Identifiable {
    public let id = UUID()
    public let photos: [Data]
    public let initialIndex: Int
}

private struct DiaryPhotoGallery: View {
    let selection: DiaryGallerySelection
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int

    init(selection: DiaryGallerySelection) {
        self.selection = selection
        _selectedIndex = State(initialValue: selection.initialIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $selectedIndex) {
                ForEach(Array(selection.photos.enumerated()), id: \.offset) {
                    index, data in
                    ZoomableDiaryImage(data: data)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.65))
            }
            .padding()
            .accessibilityLabel("action.close")
        }
    }
}

private struct ZoomableDiaryImage: View {
    let data: Data
    @State private var scale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1

    var body: some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.white)
            }
        }
        .scaleEffect(scale * gestureScale)
        .gesture(
            MagnifyGesture()
                .updating($gestureScale) { value, state, _ in
                    state = value.magnification
                }
                .onEnded { value in
                    scale = min(max(scale * value.magnification, 1), 5)
                }
        )
        .onTapGesture(count: 2) {
            withAnimation { scale = scale > 1 ? 1 : 2 }
        }
    }
}
