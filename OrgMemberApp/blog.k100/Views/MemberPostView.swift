import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import UniformTypeIdentifiers

struct MemberPostView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var memberStore: MemberStore
    @EnvironmentObject private var organizationStore: OrganizationStore

    @FocusState private var focusedField: Field?

    @State private var title = ""
    @State private var messageBody = ""

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageDataList: [(fileName: String, data: Data)] = []
    @State private var selectedPDFUrls: [URL] = []

    @State private var showPDFPicker = false
    @State private var isSubmitting = false
    @State private var showCompleteAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    enum Field {
        case title
        case body
    }

    var body: some View {
        Form {
            Section("件名") {
                TextField("件名を入力", text: $title)
                    .focused($focusedField, equals: .title)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(focusedField == .title ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }

            Section("内容") {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))

                    RoundedRectangle(cornerRadius: 12)
                        .stroke(focusedField == .body ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)

                    if messageBody.isEmpty {
                        Text("内容を入力")
                            .foregroundColor(.secondary)
                            .padding(.top, 18)
                            .padding(.leading, 18)
                    }

                    TextEditor(text: $messageBody)
                        .focused($focusedField, equals: .body)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(10)
                        .frame(minHeight: 180)
                }
            }

            Section("添付ファイル") {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("画像を添付", systemImage: "photo")
                }

                Button {
                    showPDFPicker = true
                } label: {
                    Label("PDFを添付", systemImage: "doc")
                }

                if selectedImageDataList.isEmpty && selectedPDFUrls.isEmpty {
                    Text("添付ファイルはありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(selectedImageDataList.indices, id: \.self) { index in
                        Label(selectedImageDataList[index].fileName, systemImage: "photo")
                    }
                    .onDelete {
                        selectedImageDataList.remove(atOffsets: $0)
                    }

                    ForEach(selectedPDFUrls.indices, id: \.self) { index in
                        Label(selectedPDFUrls[index].lastPathComponent, systemImage: "doc.richtext")
                    }
                    .onDelete {
                        selectedPDFUrls.remove(atOffsets: $0)
                    }
                }
            }

            Section {
                Button {
                    Task {
                        await submit()
                    }
                } label: {
                    if isSubmitting {
                        HStack {
                            ProgressView()
                            Text("送信中...")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("送信する")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(
                    isSubmitting ||
                    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }

            Section {
                NavigationLink {
                    MemberPostHistoryView()
                        .environmentObject(memberStore)
                        .environmentObject(organizationStore)
                } label: {
                    Label("投稿履歴を見る", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .navigationTitle("管理者へ投稿")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showPDFPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                selectedPDFUrls.append(contentsOf: urls)
            case .failure(let error):
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }

            Task {
                do {
                    guard let data = try await newValue.loadTransferable(type: Data.self) else {
                        return
                    }

                    selectedImageDataList.append(
                        (
                            fileName: "image_\(UUID().uuidString).jpg",
                            data: data
                        )
                    )

                    selectedPhotoItem = nil

                } catch {
                    errorMessage = "画像の読み込みに失敗しました: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
        .alert("送信しました", isPresented: $showCompleteAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("管理者へ投稿を送信しました。")
        }
        .alert("エラー", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func submit() async {
        let organizationId = organizationStore.organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let memberUid = memberStore.authUid?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let memberName = memberStore.profile?.name
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = messageBody.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !organizationId.isEmpty else {
            showError("organizationId が取得できません。")
            return
        }

        guard !memberUid.isEmpty else {
            showError("会員UIDが取得できません。")
            return
        }

        guard !trimmedTitle.isEmpty else {
            showError("件名を入力してください。")
            return
        }

        guard !trimmedBody.isEmpty else {
            showError("内容を入力してください。")
            return
        }

        isSubmitting = true

        do {
            let postRef = db.collection("organizations")
                .document(organizationId)
                .collection("memberPosts")
                .document()

            let postId = postRef.documentID

            let uploadedAttachments = try await uploadAttachments(
                organizationId: organizationId,
                postId: postId
            )

            let data: [String: Any] = [
                "memberUid": memberUid,
                "memberName": memberName,
                "title": trimmedTitle,
                "body": trimmedBody,
                "attachments": uploadedAttachments.map { $0.dictionary },
                "status": "new",
                "memberHasReadReply": true,
                "replyCount": 0,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]

            try await postRef.setData(data)

            title = ""
            messageBody = ""
            selectedImageDataList = []
            selectedPDFUrls = []

            showCompleteAlert = true

        } catch {
            showError("送信に失敗しました: \(error.localizedDescription)")
        }

        isSubmitting = false
    }

    private func uploadAttachments(
        organizationId: String,
        postId: String
    ) async throws -> [MemberPostAttachment] {

        var results: [MemberPostAttachment] = []

        for image in selectedImageDataList {
            let path = "organizations/\(organizationId)/memberPosts/\(postId)/\(image.fileName)"
            let ref = storage.reference().child(path)

            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            _ = try await ref.putDataAsync(image.data, metadata: metadata)
            let url = try await ref.downloadURL()

            results.append(
                MemberPostAttachment(
                    type: "image",
                    fileName: image.fileName,
                    url: url.absoluteString
                )
            )
        }

        for pdfUrl in selectedPDFUrls {
            let didAccess = pdfUrl.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    pdfUrl.stopAccessingSecurityScopedResource()
                }
            }

            let fileName = pdfUrl.lastPathComponent.isEmpty
                ? "file_\(UUID().uuidString).pdf"
                : pdfUrl.lastPathComponent

            let data = try Data(contentsOf: pdfUrl)

            let path = "organizations/\(organizationId)/memberPosts/\(postId)/\(fileName)"
            let ref = storage.reference().child(path)

            let metadata = StorageMetadata()
            metadata.contentType = "application/pdf"

            _ = try await ref.putDataAsync(data, metadata: metadata)
            let url = try await ref.downloadURL()

            results.append(
                MemberPostAttachment(
                    type: "pdf",
                    fileName: fileName,
                    url: url.absoluteString
                )
            )
        }

        return results
    }

    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
        isSubmitting = false
    }
}
