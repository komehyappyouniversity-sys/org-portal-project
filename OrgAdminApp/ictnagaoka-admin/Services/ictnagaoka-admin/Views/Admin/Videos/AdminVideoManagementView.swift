import SwiftUI
import Combine
import FirebaseAuth

struct AdminVideoManagementView: View {
    @EnvironmentObject var organizationStore: AdminOrganizationStore
    @StateObject private var store = AdminVideoManagementStore()

    @State private var saveAllSignal = 0

    var body: some View {
        VStack(spacing: 0) {
            headerSection
                .onAppear {
                    print("現在ログイン中 UID:", Auth.auth().currentUser?.uid ?? "nil")
                    print("現在ログイン中 email:", Auth.auth().currentUser?.email ?? "nil")
                }

            if store.isLoading {
                ProgressView("Vimeoから読み込み中...")
                    .padding()
            }

            if !store.message.isEmpty {
                Text(store.message)
                    .font(.subheadline)
                    .foregroundColor(store.isError ? .red : .green)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            if store.videos.isEmpty && !store.isLoading {
                emptySection
            } else {
                List {
                    ForEach(store.videos) { video in
                        VideoSettingRow(
                            video: video,
                            saveAllSignal: saveAllSignal,
                            onChange: { updatedVideo in
                                store.updateVideo(updatedVideo)
                            },
                            onSave: { updatedVideo in
                                store.saveVideo(
                                    updatedVideo,
                                    organizationId: resolvedOrganizationId
                                )
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("動画管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("全て保存") {
                    store.saveAll(organizationId: resolvedOrganizationId)
                    saveAllSignal += 1
                }
                .disabled(store.videos.isEmpty)
            }
        }
    }

    private var resolvedOrganizationId: String {
        let current = organizationStore.organization.id.trimmingCharacters(in: .whitespacesAndNewlines)
        return current.isEmpty ? OrganizationConfig.organizationId : current
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vimeo動画管理")
                .font(.title2.bold())

            Text("Vimeoから動画一覧を読み込み、公開範囲・有料設定・金額を保存します。")
                .font(.subheadline)
                .foregroundColor(.gray)

            Text("organizationId: \(resolvedOrganizationId)")
                .font(.caption)
                .foregroundColor(.gray)

            Button {
                store.fetchFromVimeo(organizationId: resolvedOrganizationId)
            } label: {
                Label("Vimeoから読み込み", systemImage: "arrow.down.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isLoading)
        }
        .padding()
    }

    private var emptySection: some View {
        VStack(spacing: 16) {
            Image(systemName: "video")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("まだ動画が読み込まれていません")
                .font(.headline)

            Text("上の「Vimeoから読み込み」を押すと、保存済みのVimeo設定を使って動画一覧を取得します。")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct VideoSettingRow: View {
    let video: AdminManagedVideo
    let saveAllSignal: Int
    let onChange: (AdminManagedVideo) -> Void
    let onSave: (AdminManagedVideo) -> Void

    @State private var editedVideo: AdminManagedVideo
    @State private var priceInput: String
    @State private var isSaved = false
    @State private var isEditingAfterSave = true

    init(
        video: AdminManagedVideo,
        saveAllSignal: Int,
        onChange: @escaping (AdminManagedVideo) -> Void,
        onSave: @escaping (AdminManagedVideo) -> Void
    ) {
        self.video = video
        self.saveAllSignal = saveAllSignal
        self.onChange = onChange
        self.onSave = onSave
        _editedVideo = State(initialValue: video)
        _priceInput = State(initialValue: video.price == 0 ? "" : String(video.price))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            videoHeader

            Toggle("公開する", isOn: binding(\.isPublished))
                .disabled(!isEditingAfterSave)

            Toggle("会員限定にする", isOn: binding(\.isMembersOnly))
                .disabled(!isEditingAfterSave)

            Toggle("有料 / プレミアム動画", isOn: binding(\.isPremium))
                .disabled(!isEditingAfterSave)

            if editedVideo.isPremium {
                premiumSection
            }

            Stepper("並び順: \(editedVideo.sortOrder)", value: binding(\.sortOrder), in: 0...999)
                .disabled(!isEditingAfterSave)

            HStack {
                Spacer()

                if isSaved && !isEditingAfterSave {
                    Label("保存済", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)

                    Button("再設定する") {
                        isEditingAfterSave = true
                        isSaved = false
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        saveThisRow()
                    } label: {
                        Text("この動画を保存")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 8)
        .onChange(of: saveAllSignal) { _ in
            isSaved = true
            isEditingAfterSave = false
        }
        .onChange(of: editedVideo.isPublished) { _ in
            markChanged()
            onChange(editedVideo)
        }
        .onChange(of: editedVideo.isMembersOnly) { _ in
            markChanged()
            onChange(editedVideo)
        }
        .onChange(of: editedVideo.isPremium) { _ in
            updatePriceText()
            markChanged()
            onChange(editedVideo)
        }
        .onChange(of: editedVideo.billingType) { _ in
            updatePriceText()
            markChanged()
            onChange(editedVideo)
        }
        .onChange(of: priceInput) { newValue in
            let filtered = newValue.filter { $0.isNumber }

            if filtered != newValue {
                priceInput = filtered
                return
            }

            editedVideo.price = Int(filtered) ?? 0
            updatePriceText()
            markChanged()
            onChange(editedVideo)
        }
        .onChange(of: editedVideo.sortOrder) { _ in
            markChanged()
            onChange(editedVideo)
        }
    }

    private var videoHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: editedVideo.thumbnailUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "video")
                            .foregroundColor(.gray)
                    }
            }
            .frame(width: 96, height: 60)
            .clipped()
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(editedVideo.title)
                    .font(.headline)
                    .lineLimit(2)

                if !editedVideo.description.isEmpty {
                    Text(editedVideo.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }

                Text("Vimeo ID: \(editedVideo.vimeoVideoId)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }

    private var premiumSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("課金種別", selection: binding(\.billingType)) {
                Text("月額").tag("monthly")
                Text("1本ごと").tag("oneTime")
            }
            .pickerStyle(.segmented)
            .disabled(!isEditingAfterSave)

            TextField("金額を入力 例: 1000", text: $priceInput)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .disabled(!isEditingAfterSave)

            Text(editedVideo.priceText.isEmpty ? "表示例: 月額 1,000円" : "表示: \(editedVideo.priceText)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(10)
    }

    private func saveThisRow() {
        updatePriceText()
        onSave(editedVideo)
        isSaved = true
        isEditingAfterSave = false
    }

    private func markChanged() {
        if isEditingAfterSave {
            isSaved = false
        }
    }

    private func updatePriceText() {
        guard editedVideo.isPremium else {
            editedVideo.price = 0
            editedVideo.priceText = ""
            return
        }

        let price = Int(priceInput) ?? editedVideo.price
        editedVideo.price = price

        guard price > 0 else {
            editedVideo.priceText = ""
            return
        }

        let formatted = NumberFormatter.localizedString(
            from: NSNumber(value: price),
            number: .decimal
        )

        if editedVideo.billingType == "monthly" {
            editedVideo.priceText = "月額 \(formatted)円"
        } else {
            editedVideo.priceText = "1本 \(formatted)円"
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AdminManagedVideo, Value>) -> Binding<Value> {
        Binding(
            get: {
                editedVideo[keyPath: keyPath]
            },
            set: { newValue in
                editedVideo[keyPath: keyPath] = newValue
                onChange(editedVideo)
            }
        )
    }
}
