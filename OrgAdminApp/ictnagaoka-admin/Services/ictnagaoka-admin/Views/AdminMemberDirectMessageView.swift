import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import UniformTypeIdentifiers

struct AdminDirectMessageMember: Identifiable, Hashable {
    let id: String
    let name: String
    let email: String
    let phone: String
}

struct AdminMemberDirectMessageView: View {

    @EnvironmentObject private var organizationStore: AdminOrganizationStore
    @Environment(\.dismiss) private var dismiss

    @State private var members: [AdminDirectMessageMember] = []
    @State private var selectedMember: AdminDirectMessageMember?

    @State private var title = ""
    @State private var bodyText = ""

    @State private var selectedImageItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImageName = ""

    @State private var selectedPDFData: Data?
    @State private var selectedPDFName = ""
    @State private var showPDFImporter = false

    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage = ""
    @State private var showCompleteAlert = false

    private let db = Firestore.firestore()

    private var organizationId: String {
        organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {

            Section("送信先会員") {
                if isLoading {
                    ProgressView("会員を読み込み中...")
                } else if members.isEmpty {
                    Text("会員が見つかりません")
                        .foregroundColor(.secondary)
                } else {
                    Picker("会員を選択", selection: $selectedMember) {
                        Text("未選択").tag(Optional<AdminDirectMessageMember>.none)

                        ForEach(members) { member in
                            Text(displayName(for: member))
                                .tag(Optional(member))
                        }
                    }
                }
            }

            Section("件名") {
                TextField("件名を入力", text: $title)
            }

            Section("本文") {
                TextEditor(text: $bodyText)
                    .frame(minHeight: 180)
            }

            Section("添付画像") {
                PhotosPicker(
                    selection: $selectedImageItem,
                    matching: .images
                ) {
                    Text(selectedImageName.isEmpty ? "画像を選択" : selectedImageName)
                }
                .onChange(of: selectedImageItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                            selectedImageName = "添付画像.jpg"
                        }
                    }
                }

                if selectedImageData != nil {
                    Button("画像を削除", role: .destructive) {
                        selectedImageItem = nil
                        selectedImageData = nil
                        selectedImageName = ""
                    }
                }
            }

            Section("添付PDF") {
                Button(selectedPDFName.isEmpty ? "PDFを選択" : selectedPDFName) {
                    showPDFImporter = true
                }

                if selectedPDFData != nil {
                    Button("PDFを削除", role: .destructive) {
                        selectedPDFData = nil
                        selectedPDFName = ""
                    }
                }
            }
            .fileImporter(
                isPresented: $showPDFImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let url = try result.get().first else { return }

                    guard url.startAccessingSecurityScopedResource() else {
                        errorMessage = "PDFを開けませんでした。"
                        return
                    }

                    defer {
                        url.stopAccessingSecurityScopedResource()
                    }

                    selectedPDFData = try Data(contentsOf: url)
                    selectedPDFName = url.lastPathComponent

                } catch {
                    errorMessage = "PDFの読み込みに失敗しました: \(error.localizedDescription)"
                }
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button {
                    Task {
                        await sendMessage()
                    }
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Text("この会員へ送信")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canSend)
            }
        }
        .navigationTitle("会員1人へ送信")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadMembers()
        }
        .alert("送信しました", isPresented: $showCompleteAlert) {
            Button("OK") {
                dismiss()
            }
        }
    }

    private var canSend: Bool {
        selectedMember != nil &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSending
    }

    private func displayName(for member: AdminDirectMessageMember) -> String {
        if !member.name.isEmpty {
            return member.name
        }
        if !member.email.isEmpty {
            return member.email
        }
        if !member.phone.isEmpty {
            return member.phone
        }
        return "名称未設定"
    }

    private func loadMembers() {
        guard !organizationId.isEmpty else {
            errorMessage = "organizationId が取得できません。"
            return
        }

        isLoading = true
        errorMessage = ""

        db.collection("organizations")
            .document(organizationId)
            .collection("members")
            .getDocuments { snapshot, error in
                isLoading = false

                if let error {
                    errorMessage = "会員の取得に失敗しました: \(error.localizedDescription)"
                    return
                }

                let docs = (snapshot?.documents ?? []).filter { doc in
                    let data = doc.data()

                    if let isActive = data["isActive"] as? Bool {
                        return isActive
                    }

                    let status = data["status"] as? String ?? ""
                    if status == "approved" || status == "active" {
                        return true
                    }

                    return true
                }

                print("📨 DirectMessage members count = \(docs.count)")

                members = docs.map { doc in
                    let data = doc.data()

                    let name =
                        data["displayName"] as? String ??
                        data["name"] as? String ??
                        ""

                    let email = data["email"] as? String ?? ""
                    let phone = data["phone"] as? String ?? ""

                    return AdminDirectMessageMember(
                        id: doc.documentID,
                        name: name,
                        email: email,
                        phone: phone
                    )
                }
                .sorted { displayName(for: $0) < displayName(for: $1) }
            }
    }

    private func sendMessage() async {
        guard let member = selectedMember else {
            errorMessage = "送信先の会員を選択してください。"
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty, !trimmedBody.isEmpty else {
            errorMessage = "件名と本文を入力してください。"
            return
        }

        isSending = true
        errorMessage = ""

        do {
            let attachments = try await uploadAttachments()

            let now = Timestamp(date: Date())

            let data: [String: Any] = [
                "organizationId": organizationId,
                "title": trimmedTitle,
                "body": trimmedBody,
                "createdAt": now,
                "publishedAt": now,

                // 個別送信も会員向けメッセージとして統一
                "messageType": "memberMessage",
                "targetType": "members",
                "visibility": "member",

                // 会員アプリ側で「あなた宛」と表示するための目印
                "isPersonalMessage": true,

                "isBroadcast": false,
                "targetMemberName": displayName(for: member),
                "targetMemberUids": [member.id],
                "toUids": [member.id],
                "categoryTargets": [],
                "isReadBy": [],
                "attachments": attachments,
                "createdBy": "admin"
            ]

            try await db.collection("organizations")
                .document(organizationId)
                .collection("messages")
                .addDocument(data: data)

            print("✅ 個別送信成功")
            print("✅ target uid:", member.id)
            print("✅ attachments count:", attachments.count)

            isSending = false
            showCompleteAlert = true

        } catch {
            isSending = false
            errorMessage = "送信に失敗しました: \(error.localizedDescription)"
            print("❌ 個別送信失敗:", error.localizedDescription)
        }
    }

    private func uploadAttachments() async throws -> [[String: Any]] {
        var attachments: [[String: Any]] = []

        let messageId = UUID().uuidString
        let storage = Storage.storage()

        if let imageData = selectedImageData {
            let path = "organizations/\(organizationId)/messages/\(messageId)/image.jpg"
            let ref = storage.reference().child(path)

            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let url = try await ref.downloadURL()

            attachments.append([
                "type": "image",
                "name": selectedImageName.isEmpty ? "添付画像.jpg" : selectedImageName,
                "url": url.absoluteString,
                "storagePath": path
            ])
        }

        if let pdfData = selectedPDFData {
            let fileName = selectedPDFName.isEmpty ? "attachment.pdf" : selectedPDFName
            let path = "organizations/\(organizationId)/messages/\(messageId)/\(fileName)"
            let ref = storage.reference().child(path)

            let metadata = StorageMetadata()
            metadata.contentType = "application/pdf"

            _ = try await ref.putDataAsync(pdfData, metadata: metadata)
            let url = try await ref.downloadURL()

            attachments.append([
                "type": "pdf",
                "name": fileName,
                "url": url.absoluteString,
                "storagePath": path
            ])
        }

        return attachments
    }
}
