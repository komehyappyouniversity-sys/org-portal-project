import SwiftUI
import Combine
import PhotosUI
import FirebaseFirestore
import FirebaseStorage
import UIKit

@MainActor
final class OrganizationLogoSettingsStore: ObservableObject {

    @Published var selectedItem: PhotosPickerItem?
    @Published var selectedImageData: Data?
    @Published var currentLogoImageURL = ""

    // 🔥 追加
    @Published var logoDisplayHeight: Double = 260

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage = ""
    @Published var successMessage = ""

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    func load(organizationId: String) async {

        isLoading = true
        errorMessage = ""
        successMessage = ""

        do {

            let document = try await db.collection("organizations")
                .document(organizationId)
                .getDocument()

            let data = document.data() ?? [:]

            currentLogoImageURL =
                data["logoImageURL"] as? String ?? ""

            // 🔥 追加
            logoDisplayHeight =
                data["logoDisplayHeight"] as? Double ?? 260

        } catch {

            errorMessage = "ロゴ情報の読み込みに失敗しました。"

            print(
                "❌ logo load error:",
                error.localizedDescription
            )
        }

        isLoading = false
    }

    func loadSelectedImage() async {

        guard let selectedItem else {
            return
        }

        do {

            if let data = try await selectedItem
                .loadTransferable(type: Data.self) {

                selectedImageData = data
                errorMessage = ""
            }

        } catch {

            errorMessage = "画像の読み込みに失敗しました。"

            print(
                "❌ image load error:",
                error.localizedDescription
            )
        }
    }

    func saveLogo(organizationId: String) async {

        isSaving = true
        errorMessage = ""
        successMessage = ""

        do {

            var updateData: [String: Any] = [
                "logoDisplayHeight": logoDisplayHeight,
                "updatedAt": FieldValue.serverTimestamp()
            ]

            // 🔥 新しい画像がある場合のみアップロード
            if let selectedImageData {

                let path =
                    "organizations/\(organizationId)/logo/logo.jpg"

                let ref = storage.reference().child(path)

                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"

                _ = try await ref.putDataAsync(
                    selectedImageData,
                    metadata: metadata
                )

                let url = try await ref.downloadURL()

                updateData["logoImageURL"] = url.absoluteString

                currentLogoImageURL = url.absoluteString

                print(
                    "✅ logo saved:",
                    url.absoluteString
                )
            }

            try await db.collection("organizations")
                .document(organizationId)
                .setData(
                    updateData,
                    merge: true
                )

            successMessage =
                "組織ロゴ設定を保存しました。"

        } catch {

            errorMessage =
                "組織ロゴの保存に失敗しました。"

            print(
                "❌ logo save error:",
                error.localizedDescription
            )
        }

        isSaving = false
    }
}

struct OrganizationLogoSettingsView: View {

    let organization: OrganizationItem

    @StateObject private var store =
        OrganizationLogoSettingsStore()

    var body: some View {

        Form {

            Section("対象組織") {

                row(
                    title: "組織名",
                    value: organization.name
                )

                row(
                    title: "organizationId",
                    value: organization.id
                )
            }

            // MARK: - 現在のロゴ

            Section("現在のロゴ") {

                if let url = URL(
                    string: store.currentLogoImageURL
                ),
                !store.currentLogoImageURL.isEmpty {

                    AsyncImage(url: url) { phase in

                        switch phase {

                        case .empty:

                            ProgressView()

                        case .success(let image):

                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(
                                    height:
                                        store.logoDisplayHeight
                                )
                                .cornerRadius(16)

                        case .failure:

                            Text(
                                "現在のロゴを表示できませんでした"
                            )
                            .foregroundColor(.red)

                        @unknown default:

                            EmptyView()
                        }
                    }

                } else {

                    Text("ロゴはまだ設定されていません")
                        .foregroundColor(.secondary)
                }
            }

            // MARK: - サイズ調整

            Section("ロゴサイズ調整") {

                VStack(alignment: .leading, spacing: 16) {

                    Text(
                        "会員アプリ表示高さ: \(Int(store.logoDisplayHeight))"
                    )
                    .font(.headline)

                    Slider(
                        value: $store.logoDisplayHeight,
                        in: 120...500,
                        step: 10
                    )

                    Text(
                        "このサイズで会員アプリに表示されます。"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            // MARK: - 新しいロゴ

            Section("新しいロゴ") {

                PhotosPicker(
                    selection: $store.selectedItem,
                    matching: .images
                ) {

                    Label(
                        "画像を選択",
                        systemImage: "photo"
                    )
                }

                if let data = store.selectedImageData,
                   let uiImage = UIImage(data: data) {

                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(
                            height: store.logoDisplayHeight
                        )
                        .cornerRadius(16)
                }
            }

            // MARK: - 保存

            Section {

                Button {

                    Task {

                        await store.saveLogo(
                            organizationId: organization.id
                        )
                    }

                } label: {

                    if store.isSaving {

                        ProgressView()
                            .frame(maxWidth: .infinity)

                    } else {

                        Text("ロゴ設定を保存")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(store.isSaving)
            }

            if store.isLoading {

                Section {

                    ProgressView("読み込み中...")
                }
            }

            if !store.errorMessage.isEmpty {

                Section {

                    Text(store.errorMessage)
                        .foregroundColor(.red)
                }
            }

            if !store.successMessage.isEmpty {

                Section {

                    Text(store.successMessage)
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("組織ロゴ設定")
        .navigationBarTitleDisplayMode(.inline)

        .task {

            await store.load(
                organizationId: organization.id
            )
        }

        .onChange(of: store.selectedItem) {

            Task {

                await store.loadSelectedImage()
            }
        }
    }

    private func row(
        title: String,
        value: String
    ) -> some View {

        HStack {

            Text(title)

            Spacer()

            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
