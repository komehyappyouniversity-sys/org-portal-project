import SwiftUI
import Combine

struct AdminVideoManagementView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @StateObject private var store = AdminVideoManagementStore()

    var body: some View {
        VStack(spacing: 0) {
            headerSection

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
                            onChange: { updatedVideo in
                                store.updateVideo(updatedVideo)
                            },
                            onSave: { updatedVideo in
                                store.saveVideo(
                                    updatedVideo,
                                    organizationId: organizationStore.organizationId
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
                    store.saveAll(organizationId: organizationStore.organizationId)
                }
                .disabled(store.videos.isEmpty)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vimeo動画管理")
                .font(.title2.bold())

            Text("Vimeoから動画一覧を読み込み、公開範囲・有料設定・金額を保存します。")
                .font(.subheadline)
                .foregroundColor(.gray)

            Text("organizationId: \(organizationStore.organizationId)")
                .font(.caption)
                .foregroundColor(.gray)

            HStack {
                Button {
                    store.fetchFromVimeo(organizationId: organizationStore.organizationId)
                } label: {
                    Label("Vimeoから読み込み", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.saveAll(organizationId: organizationStore.organizationId)
                } label: {
                    Label("全て保存", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.videos.isEmpty)
            }
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

            Text("「Vimeoから読み込み」を押すと、保存済みのVimeo設定を使って動画一覧を取得します。")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                store.fetchFromVimeo(organizationId: organizationStore.organizationId)
            } label: {
                Text("Vimeoから読み込み")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding()
    }
}

private struct VideoSettingRow: View {
    let video: AdminManagedVideo
    let onChange: (AdminManagedVideo) -> Void
    let onSave: (AdminManagedVideo) -> Void

    @State private var editedVideo: AdminManagedVideo
    @State private var priceInput: String

    init(
        video: AdminManagedVideo,
        onChange: @escaping (AdminManagedVideo) -> Void,
        onSave: @escaping (AdminManagedVideo) -> Void
    ) {
        self.video = video
        self.onChange = onChange
        self.onSave = onSave
        _editedVideo = State(initialValue: video)
        _priceInput = State(initialValue: video.price == 0 ? "" : String(video.price))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            videoHeader

            Toggle("公開する", isOn: binding(\.isPublished))
            Toggle("会員限定にする", isOn: binding(\.isMembersOnly))
            Toggle("有料 / プレミアム動画", isOn: binding(\.isPremium))

            if editedVideo.isPremium {
                premiumSection
            }

            Stepper("並び順: \(editedVideo.sortOrder)", value: binding(\.sortOrder), in: 0...999)

            HStack {
                Spacer()

                Button {
                    updatePriceText()
                    onSave(editedVideo)
                } label: {
                    Text("この動画を保存")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 8)
        .onChange(of: editedVideo.isPublished) { _ in onChange(editedVideo) }
        .onChange(of: editedVideo.isMembersOnly) { _ in onChange(editedVideo) }
        .onChange(of: editedVideo.isPremium) { _ in
            updatePriceText()
            onChange(editedVideo)
        }
        .onChange(of: editedVideo.billingType) { _ in
            updatePriceText()
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
            onChange(editedVideo)
        }
        .onChange(of: editedVideo.sortOrder) { _ in onChange(editedVideo) }
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

            TextField("金額を入力 例: 1000", text: $priceInput)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            Text(editedVideo.priceText.isEmpty ? "表示例: 月額 1,000円" : "表示: \(editedVideo.priceText)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(10)
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
