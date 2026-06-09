import SwiftUI
import PhotosUI
import FirebaseStorage
import UniformTypeIdentifiers
import UIKit

struct SharedManualEditView: View {

    @ObservedObject var store: SharedManualStore

    let manual: SharedManualItem?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var bodyText: String
    @State private var sortOrderText: String
    @State private var isPublished: Bool
    @State private var attachments: [SharedManualAttachment]

    @State private var selectedImageItem: PhotosPickerItem?
    @State private var selectedPDFURL: URL?

    @State private var showPDFPicker = false
    @State private var showURLInput = false
    @State private var urlTitle = ""
    @State private var urlString = ""

    @State private var isUploading = false
    @State private var localErrorMessage = ""

    private let storage = Storage.storage()
    private let workingManualId: String

    init(
        store: SharedManualStore,
        manual: SharedManualItem?
    ) {
        self.store = store
        self.manual = manual
        self.workingManualId = manual?.id ?? UUID().uuidString

        _title = State(initialValue: manual?.title ?? "")
        _bodyText = State(initialValue: manual?.body ?? "")
        _sortOrderText = State(
            initialValue: manual.map { String($0.sortOrder) } ?? "1"
        )
        _isPublished = State(initialValue: manual?.isPublished ?? true)
        _attachments = State(initialValue: manual?.attachments ?? [])
    }

    var body: some View {
        Form {

            Section("基本情報") {

                TextField("タイトル", text: $title)

                TextField("表示順", text: $sortOrderText)
                    .keyboardType(.numberPad)

                Toggle("公開する", isOn: $isPublished)
            }

            Section("本文") {

                TextEditor(text: $bodyText)
                    .frame(minHeight: 240)
            }

            Section("添付ファイル") {

                PhotosPicker(
                    selection: $selectedImageItem,
                    matching: .images
                ) {
                    Label("画像を追加", systemImage: "photo")
                }

                Button {
                    showPDFPicker = true
                } label: {
                    Label("PDFを追加", systemImage: "doc.richtext")
                }

                Button {
                    showURLInput = true
                } label: {
                    Label("URLを追加", systemImage: "link")
                }

                if isUploading {
                    ProgressView("アップロード中...")
                }

                if attachments.isEmpty {
                    Text("添付ファイルはありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(attachments) { attachment in
                        attachmentRow(attachment)
                    }
                    .onDelete { indexSet in
                        deleteAttachments(at: indexSet)
                    }
                }
            }

            if !localErrorMessage.isEmpty {
                Section("エラー") {
                    Text(localErrorMessage)
                        .foregroundColor(.red)
                }
            }

            if !store.errorMessage.isEmpty {
                Section("エラー") {
                    Text(store.errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(manual == nil ? "新規マニュアル" : "マニュアル編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {

            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(isUploading)
            }
        }
        .fileImporter(
            isPresented: $showPDFPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handlePDFImport(result)
        }
        .alert("URLを追加", isPresented: $showURLInput) {
            TextField("表示名 例: 操作説明ページ", text: $urlTitle)
            TextField("URL https://...", text: $urlString)

            Button("キャンセル", role: .cancel) {
                urlTitle = ""
                urlString = ""
            }

            Button("追加") {
                addURLAttachment()
            }
        } message: {
            Text("外部ページや動画URLを登録できます。")
        }
        .onChange(of: selectedImageItem) {
            Task {
                await uploadSelectedImage()
            }
        }
    }

    @ViewBuilder
    private func attachmentRow(
        _ attachment: SharedManualAttachment
    ) -> some View {

        HStack(alignment: .top, spacing: 12) {

            Image(systemName: iconName(for: attachment.type))
                .foregroundColor(.blue)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.name.isEmpty ? "添付ファイル" : attachment.name)
                    .font(.body)

                Text(attachment.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let url = URL(string: attachment.url) {
                    Link("開く", destination: url)
                        .font(.caption.bold())
                }
            }

            Spacer()

            Button(role: .destructive) {
                deleteAttachment(attachment)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private func iconName(for type: String) -> String {
        switch type {
        case "image":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "url":
            return "link"
        default:
            return "paperclip"
        }
    }

    private func uploadSelectedImage() async {
        guard let imageItem = selectedImageItem else { return }

        localErrorMessage = ""
        isUploading = true

        do {
            guard let data = try await imageItem
                .loadTransferable(type: Data.self) else {

                localErrorMessage = "画像データを読み込めませんでした。"
                isUploading = false
                return
            }

            guard let uiImage = UIImage(data: data),
                  let pngData = uiImage.pngData() else {

                localErrorMessage = "画像をPNG形式に変換できませんでした。"
                isUploading = false
                return
            }

            let attachmentId = UUID().uuidString
            let path =
                "sharedManuals/\(workingManualId)/attachments/\(attachmentId).png"

            let ref = storage.reference().child(path)

            let metadata = StorageMetadata()
            metadata.contentType = "image/png"

            _ = try await ref.putDataAsync(
                pngData,
                metadata: metadata
            )

            let url = try await ref.downloadURL()

            attachments.append(
                SharedManualAttachment(
                    id: attachmentId,
                    type: "image",
                    name: "画像",
                    url: url.absoluteString
                )
            )

            selectedImageItem = nil

        } catch {
            localErrorMessage =
                "画像のアップロードに失敗しました: \(error.localizedDescription)"
        }

        isUploading = false
    }

    private func handlePDFImport(
        _ result: Result<[URL], Error>
    ) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            Task {
                await uploadPDF(url)
            }

        case .failure(let error):
            localErrorMessage =
                "PDFの選択に失敗しました: \(error.localizedDescription)"
        }
    }

    private func uploadPDF(_ url: URL) async {
        localErrorMessage = ""
        isUploading = true

        do {
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)

            let attachmentId = UUID().uuidString
            let fileName = url.lastPathComponent
            let path =
                "sharedManuals/\(workingManualId)/attachments/\(attachmentId)-\(fileName)"

            let ref = storage.reference().child(path)

            let metadata = StorageMetadata()
            metadata.contentType = "application/pdf"

            _ = try await ref.putDataAsync(
                data,
                metadata: metadata
            )

            let downloadURL = try await ref.downloadURL()

            attachments.append(
                SharedManualAttachment(
                    id: attachmentId,
                    type: "pdf",
                    name: fileName,
                    url: downloadURL.absoluteString
                )
            )

        } catch {
            localErrorMessage =
                "PDFのアップロードに失敗しました: \(error.localizedDescription)"
        }

        isUploading = false
    }

    private func addURLAttachment() {
        localErrorMessage = ""

        let trimmedURL = urlString.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard let url = URL(string: trimmedURL),
              url.scheme == "http" || url.scheme == "https" else {

            localErrorMessage = "正しいURLを入力してください。"
            return
        }

        let trimmedTitle = urlTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        attachments.append(
            SharedManualAttachment(
                type: "url",
                name: trimmedTitle.isEmpty ? trimmedURL : trimmedTitle,
                url: trimmedURL
            )
        )

        urlTitle = ""
        urlString = ""
    }

    private func save() {
        let sortOrder = Int(sortOrderText) ?? 1

        Task {
            if let manual {
                await store.updateManual(
                    manualId: manual.id,
                    title: title,
                    body: bodyText,
                    sortOrder: sortOrder,
                    isPublished: isPublished,
                    attachments: attachments
                )
            } else {
                await store.createManual(
                    manualId: workingManualId,
                    title: title,
                    body: bodyText,
                    sortOrder: sortOrder,
                    isPublished: isPublished,
                    attachments: attachments
                )
            }

            if store.errorMessage.isEmpty {
                dismiss()
            }
        }
    }

    private func deleteAttachments(at indexSet: IndexSet) {
        let targets = indexSet.compactMap { index in
            attachments.indices.contains(index) ? attachments[index] : nil
        }

        attachments.remove(atOffsets: indexSet)

        for attachment in targets {
            deleteStoredFileIfNeeded(for: attachment)
        }
    }

    private func deleteAttachment(_ attachment: SharedManualAttachment) {
        attachments.removeAll { $0.id == attachment.id }
        deleteStoredFileIfNeeded(for: attachment)
    }

    private func deleteStoredFileIfNeeded(
        for attachment: SharedManualAttachment
    ) {
        guard attachment.type == "image" || attachment.type == "pdf" else {
            return
        }

        Task {
            do {
                let ref = storage.reference(forURL: attachment.url)
                try await ref.delete()
            } catch {
                localErrorMessage =
                    "添付ファイルの削除に失敗しました: \(error.localizedDescription)"
            }
        }
    }
}
