import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import UniformTypeIdentifiers

struct AdminMessageComposerView: View {

    @EnvironmentObject var organizationStore: AdminOrganizationStore

    @State private var title = ""
    @State private var bodyText = ""
    @State private var zoomURL = ""
    @State private var videoURL = ""

    @State private var sendMode: SendMode = .allMembers
    @State private var categories: [String] = []
    @State private var selectedCategories: Set<String> = []

    @State private var selectedImageItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedUIImage: UIImage?
    @State private var selectedImageName = ""

    @State private var selectedPDFData: Data?
    @State private var selectedPDFName = ""

    @State private var isShowingPDFPicker = false
    @State private var isLoadingCategories = false
    @State private var isSending = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    private var organizationId: String {
        let current = organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return current.isEmpty
            ? OrganizationConfig.organizationId
            : current
    }

    enum SendMode: String, CaseIterable, Identifiable {
        case allMembers = "全会員"
        case category = "カテゴリ別"

        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                Text("会員へ一斉送信")
                    .font(.title2.bold())

                Picker("送信対象", selection: $sendMode) {
                    ForEach(SendMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if sendMode == .category {
                    categorySection
                }

                TextField("タイトル", text: $title)
                    .textFieldStyle(.roundedBorder)

                TextEditor(text: $bodyText)
                    .frame(minHeight: 160)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3))
                    )

                TextField("Zoom URL（任意）", text: $zoomURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)

                TextField("動画URL（任意）", text: $videoURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)

                attachmentSection

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button {
                    Task {
                        await sendMessage()
                    }
                } label: {
                    HStack {
                        if isSending {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(isSending ? "送信中..." : "会員へ送信")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSend ? Color.blue : Color.gray.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canSend || isSending)
            }
            .padding()
        }
        .navigationTitle("会員へ一斉送信")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCategories()
        }
        .onChange(of: selectedImageItem) { _, newItem in
            Task {
                await loadImage(from: newItem)
            }
        }
        .fileImporter(
            isPresented: $isShowingPDFPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handlePDFImport(result)
        }
        .alert("送信しました", isPresented: $showSuccess) {
            Button("OK") {
                resetForm()
            }
        } message: {
            Text("会員向けメッセージを送信しました。")
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("送信カテゴリ")
                .font(.headline)

            if isLoadingCategories {
                ProgressView("カテゴリ読み込み中...")
            } else if categories.isEmpty {
                Text("カテゴリが登録されていません。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(categories, id: \.self) { category in
                    Button {
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedCategories.contains(category) ? "checkmark.circle.fill" : "circle")
                            Text(category)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(10)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }

    private var attachmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("添付")
                .font(.headline)

            PhotosPicker(
                selection: $selectedImageItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text(selectedImageName.isEmpty ? "画像を選択" : "画像: \(selectedImageName)")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.18))
                    .cornerRadius(10)
            }

            if let selectedUIImage {
                Image(uiImage: selectedUIImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.25))
                    )

                Text("この画像が添付されます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                isShowingPDFPicker = true
            } label: {
                Text(selectedPDFName.isEmpty ? "PDFを選択" : "PDF: \(selectedPDFName)")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.18))
                    .cornerRadius(10)
            }

            if !selectedImageName.isEmpty || !selectedPDFName.isEmpty {
                Button("添付をクリア") {
                    clearAttachments()
                }
                .font(.footnote)
                .foregroundColor(.red)
            }
        }
    }

    private var canSend: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasBody = !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if sendMode == .category {
            return hasTitle && hasBody && !selectedCategories.isEmpty
        }

        return hasTitle && hasBody
    }

    private func loadCategories() async {
        isLoadingCategories = true
        errorMessage = ""

        do {
            let snapshot = try await db
                .collection("organizations")
                .document(organizationId)
                .collection("members")
                .getDocuments()

            var categorySet = Set<String>()

            for document in snapshot.documents {
                let data = document.data()

                if let categories = data["categories"] as? [String] {
                    for category in categories {
                        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            categorySet.insert(trimmed)
                        }
                    }
                }

                if let category = data["category"] as? String {
                    let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        categorySet.insert(trimmed)
                    }
                }
            }

            categories = Array(categorySet).sorted()
            print("✅ categories loaded:", categories)

        } catch {
            errorMessage = "カテゴリの読み込みに失敗しました: \(error.localizedDescription)"
            print("❌ categories load error:", error.localizedDescription)
        }

        isLoadingCategories = false
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "画像データを読み込めませんでした。"
                return
            }

            selectedImageData = data
            selectedUIImage = UIImage(data: data)
            selectedImageName = "message_image.jpg"

            print("✅ 画像読み込み成功 size:", data.count)
        } catch {
            errorMessage = "画像の読み込みに失敗しました: \(error.localizedDescription)"
            print("❌ 画像読み込み失敗:", error.localizedDescription)
        }
    }

    private func handlePDFImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "PDFファイルを開けませんでした。"
                return
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            selectedPDFData = try Data(contentsOf: url)
            selectedPDFName = url.lastPathComponent

            print("✅ PDF読み込み成功:", selectedPDFName)

        } catch {
            errorMessage = "PDFの読み込みに失敗しました: \(error.localizedDescription)"
            print("❌ PDF読み込み失敗:", error.localizedDescription)
        }
    }

    private func sendMessage() async {
        isSending = true
        errorMessage = ""

        do {
            let messageRef = db
                .collection("organizations")
                .document(organizationId)
                .collection("messages")
                .document()

            var attachments: [[String: Any]] = []

            if let selectedImageData {
                let imageURL = try await uploadAttachment(
                    data: selectedImageData,
                    path: "organizations/\(organizationId)/messages/\(messageRef.documentID)/image.jpg",
                    contentType: "image/jpeg"
                )

                attachments.append([
                    "type": "image",
                    "name": selectedImageName,
                    "url": imageURL
                ])
            }

            if let selectedPDFData {
                let safePDFName = selectedPDFName.isEmpty ? "attachment.pdf" : selectedPDFName

                let pdfURL = try await uploadAttachment(
                    data: selectedPDFData,
                    path: "organizations/\(organizationId)/messages/\(messageRef.documentID)/\(safePDFName)",
                    contentType: "application/pdf"
                )

                attachments.append([
                    "type": "pdf",
                    "name": safePDFName,
                    "url": pdfURL
                ])
            }

            let categoryTargets: [String]
            if sendMode == .category {
                categoryTargets = Array(selectedCategories).sorted()
            } else {
                categoryTargets = []
            }

            let data: [String: Any] = [
                "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
                "body": bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                "organizationId": organizationId,
                "messageType": "memberMessage",
                "isBroadcast": sendMode == .allMembers,
                "categoryTargets": categoryTargets,
                "targetMemberUids": [],
                "toUids": [],
                "isReadBy": [],
                "attachments": attachments,
                "zoomURL": zoomURL.trimmingCharacters(in: .whitespacesAndNewlines),
                "videoURL": videoURL.trimmingCharacters(in: .whitespacesAndNewlines),
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]

            try await messageRef.setData(data)

            print("✅ 会員メッセージ送信成功")
            print("categoryTargets:", categoryTargets)
            print("attachments:", attachments)

            showSuccess = true

        } catch {
            errorMessage = "送信に失敗しました: \(error.localizedDescription)"
            print("❌ 会員メッセージ送信失敗:", error.localizedDescription)
        }

        isSending = false
    }

    private func uploadAttachment(
        data: Data,
        path: String,
        contentType: String
    ) async throws -> String {

        let ref = storage.reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = contentType

        return try await withCheckedThrowingContinuation { continuation in
            ref.putData(data, metadata: metadata) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                ref.downloadURL { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let url else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "StorageUpload",
                                code: -1,
                                userInfo: [
                                    NSLocalizedDescriptionKey: "アップロード後のURL取得に失敗しました。"
                                ]
                            )
                        )
                        return
                    }

                    continuation.resume(returning: url.absoluteString)
                }
            }
        }
    }

    private func clearAttachments() {
        selectedImageItem = nil
        selectedImageData = nil
        selectedUIImage = nil
        selectedImageName = ""
        selectedPDFData = nil
        selectedPDFName = ""
    }

    private func resetForm() {
        title = ""
        bodyText = ""
        zoomURL = ""
        videoURL = ""
        sendMode = .allMembers
        selectedCategories = []
        clearAttachments()
        errorMessage = ""
    }
}
