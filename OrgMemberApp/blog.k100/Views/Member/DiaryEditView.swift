import SwiftUI
import PhotosUI

struct DiaryEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var memberStore: MemberStore
    @EnvironmentObject var organizationStore: OrganizationStore
    @ObservedObject var store: DiaryStore

    let entry: DiaryEntry

    @State private var date: Date
    @State private var titleText: String
    @State private var bodyText: String
    @State private var existingImageUrls: [String]
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var newSelectedImages: [PhotoPickerItem] = []
    @State private var showSaveErrorAlert = false
    @State private var saveErrorText = ""

    init(store: DiaryStore, entry: DiaryEntry) {
        self.store = store
        self.entry = entry
        _date = State(initialValue: entry.date)
        _titleText = State(initialValue: entry.title)
        _bodyText = State(initialValue: entry.body)
        _existingImageUrls = State(initialValue: entry.imageUrls)
    }

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

                    TextField("タイトルを入力", text: $titleText)
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
                        Text("登録済み写真")
                            .font(.headline)
                        Spacer()
                    }

                    if existingImageUrls.isEmpty {
                        Text("画像はありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(existingImageUrls, id: \.self) { url in
                                    ZStack(alignment: .topTrailing) {
                                        AsyncImage(url: URL(string: url)) { phase in
                                            switch phase {
                                            case .empty:
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .fill(Color(.systemGray5))
                                                    ProgressView()
                                                }

                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()

                                            case .failure:
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .fill(Color(.systemGray5))
                                                    Image(systemName: "photo")
                                                        .font(.title2)
                                                        .foregroundStyle(.secondary)
                                                }

                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .frame(width: 110, height: 110)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        )

                                        Button {
                                            existingImageUrls.removeAll { $0 == url }
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

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("新しい写真")
                            .font(.headline)

                        Spacer()

                        PhotosPicker(
                            selection: $selectedPickerItems,
                            maxSelectionCount: 10,
                            matching: .images
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("画像を追加")
                                    .fontWeight(.bold)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    if !newSelectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(newSelectedImages) { item in
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
                                            newSelectedImages.removeAll { $0.id == item.id }
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
                    update()
                } label: {
                    HStack {
                        if store.isSaving {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(store.isSaving ? "保存中..." : "変更を保存")
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
        .navigationTitle("日記を編集")
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

            newSelectedImages = loaded
        }
    }

    private func update() {
        guard let uid = memberStore.authUid else {
            saveErrorText = "ユーザー情報を取得できませんでした。"
            showSaveErrorAlert = true
            return
        }

        store.updateEntry(
            organizationId: OrganizationConfig.organizationId,
            uid: uid,
            entryId: entry.id,
            date: date,
            title: titleText,
            body: bodyText,
            existingImageUrls: existingImageUrls,
            newImageDatas: newSelectedImages.map(\.data),
            originalImageUrls: entry.imageUrls   // 🔥 これを追加
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
