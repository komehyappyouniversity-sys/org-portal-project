import SwiftUI
import PhotosUI

struct DiaryCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var memberStore: MemberStore
    @EnvironmentObject var organizationStore: OrganizationStore
    @ObservedObject var store: DiaryStore

    @State private var date = Date()
    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [PhotoPickerItem] = []
    @State private var showSaveErrorAlert = false
    @State private var saveErrorText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("日付")
                        .font(.headline)

                    DatePicker(
                        "",
                        selection: $date,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("タイトル")
                        .font(.headline)

                    TextField("タイトルを入力", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("本文")
                        .font(.headline)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBackground))

                        if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("本文を入力")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.top, 14)
                        }

                        TextEditor(text: $bodyText)
                            .frame(minHeight: 220)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("写真")
                            .font(.headline)

                        Spacer()

                        PhotosPicker(
                            selection: $selectedPickerItems,
                            maxSelectionCount: 10,
                            matching: .images
                        ) {
                            Label("画像を選ぶ", systemImage: "photo.on.rectangle")
                                .font(.subheadline.bold())
                        }
                    }

                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(selectedImages) { item in
                                    ZStack(alignment: .topTrailing) {
                                        if let uiImage = UIImage(data: item.data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 110, height: 110)
                                                .clipShape(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                )
                                        }

                                        Button {
                                            removeSelectedImage(item)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(.white, .black.opacity(0.7))
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Button {
                    save()
                } label: {
                    HStack {
                        if store.isSaving {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(store.isSaving ? "保存中..." : "保存する")
                            .font(.headline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(canSave ? Color.blue : Color.gray)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSave || store.isSaving)
            }
            .padding(20)
        }
        .background(Color(.systemGray6))
        .navigationTitle("日記を書く")
        .navigationBarTitleDisplayMode(.inline)
        .alert("保存できませんでした", isPresented: $showSaveErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorText)
        }
        .onChange(of: selectedPickerItems) { _, newItems in
            loadSelectedImages(from: newItems)
        }
    }

    private var canSave: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadSelectedImages(from items: [PhotosPickerItem]) {
        Task {
            var loaded: [PhotoPickerItem] = []

            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    loaded.append(PhotoPickerItem(data: data))
                }
            }

            selectedImages = loaded
        }
    }

    private func removeSelectedImage(_ item: PhotoPickerItem) {
        selectedImages.removeAll { $0.id == item.id }
    }

    private func save() {
        guard let uid = memberStore.authUid else {
            saveErrorText = "ユーザー情報を取得できませんでした。"
            showSaveErrorAlert = true
            return
        }

        store.saveEntry(
            organizationId: OrganizationConfig.organizationId,
            uid: uid,
            date: date,
            title: title,
            body: bodyText,
            imageDatas: selectedImages.map(\.data)
        ) { result in
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                saveErrorText = error.localizedDescription
                showSaveErrorAlert = true
            }
        }
    }
}
