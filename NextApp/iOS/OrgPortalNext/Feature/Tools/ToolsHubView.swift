import DesignSystem
import Model
import SwiftUI
import WebKit

public struct ToolsHubView: View {
    private enum Destination: Identifiable {
        case schedule
        case diary
        case denomination
        case meetingMinutes
        case snsPostingAssistant
        case favorites
        case friends
        case manual
        case distributedVideos
        case distributedVideoPlayer(DistributedVideo)

        var id: String {
            switch self {
            case .schedule: "schedule"
            case .diary: "diary"
            case .denomination: "denomination"
            case .meetingMinutes: "meetingMinutes"
            case .snsPostingAssistant: "snsPostingAssistant"
            case .favorites: "favorites"
            case .friends: "friends"
            case .manual: "manual"
            case .distributedVideos: "distributedVideos"
            case let .distributedVideoPlayer(video): "distributedVideoPlayer:\(video.id)"
            }
        }
    }

    @ObservedObject private var scheduleModel: ScheduleFeatureModel
    @ObservedObject private var diaryModel: DiaryFeatureModel
    @ObservedObject private var cashDistributionModel: CashDistributionFeatureModel
    @ObservedObject private var meetingMinutesModel: MeetingMinutesFeatureModel
    @ObservedObject private var snsPostingAssistantModel: SnsPostingAssistantFeatureModel
    @ObservedObject private var favoriteBookmarkModel: FavoriteBookmarkFeatureModel
    @ObservedObject private var friendExchangeModel: FriendExchangeFeatureModel
    @ObservedObject private var distributedVideoModel: DistributedVideoFeatureModel
    @State private var destination: Destination?

    public init(
        scheduleModel: ScheduleFeatureModel,
        diaryModel: DiaryFeatureModel,
        cashDistributionModel: CashDistributionFeatureModel,
        meetingMinutesModel: MeetingMinutesFeatureModel,
        snsPostingAssistantModel: SnsPostingAssistantFeatureModel,
        favoriteBookmarkModel: FavoriteBookmarkFeatureModel,
        friendExchangeModel: FriendExchangeFeatureModel,
        distributedVideoModel: DistributedVideoFeatureModel
    ) {
        self.scheduleModel = scheduleModel
        self.diaryModel = diaryModel
        self.cashDistributionModel = cashDistributionModel
        self.meetingMinutesModel = meetingMinutesModel
        self.snsPostingAssistantModel = snsPostingAssistantModel
        self.favoriteBookmarkModel = favoriteBookmarkModel
        self.friendExchangeModel = friendExchangeModel
        self.distributedVideoModel = distributedVideoModel
    }

    public var body: some View {
        NavigationStack {
            List {
                Button {
                    destination = .schedule
                } label: {
                    FeatureCard(
                        "screen.schedule.list",
                        subtitle: "home.schedule.subtitle",
                        systemImage: "calendar"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .meetingMinutes
                } label: {
                    FeatureCard(
                        "home.meeting_minutes.title",
                        subtitle: "home.meeting_minutes.subtitle",
                        systemImage: "mic"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .diary
                } label: {
                    FeatureCard(
                        "screen.diary.list",
                        subtitle: "home.diary.subtitle",
                        systemImage: "book.closed"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .denomination
                } label: {
                    FeatureCard(
                        "home.denomination.title",
                        subtitle: "home.denomination.subtitle",
                        systemImage: "yensign.circle"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .snsPostingAssistant
                } label: {
                    FeatureCard(
                        "SNS投稿補助",
                        subtitle: "文章をコピーして外部SNSを開きます。",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .favorites
                } label: {
                    FeatureCard(
                        "お気に入り",
                        subtitle: "よく見るWebページを自分専用に保存します。",
                        systemImage: "bookmark"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .distributedVideos
                } label: {
                    FeatureCard(
                        "配信動画",
                        subtitle: "Vimeo配信動画を一覧で開き再生できます。",
                        systemImage: "play.rectangle"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .friends
                } label: {
                    FeatureCard(
                        "友達情報・交流履歴帳",
                        subtitle: "本人だけが見られる友達情報と交流履歴を端末内に保存します。",
                        systemImage: "person.2"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .manual
                } label: {
                    FeatureCard(
                        "使い方マニュアル",
                        subtitle: "アプリの主要機能をすばやく確認できます。",
                        systemImage: "book.closed"
                    )
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("tab.tools")
        }
        .sheet(item: $destination) { destination in
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        self.destination = nil
                    } label: {
                        Label("action.close", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                switch destination {
                case .schedule:
                    ScheduleListView(model: scheduleModel)
                case .diary:
                    DiaryRootView(model: diaryModel)
                case .denomination:
                    DenominationToolView(model: cashDistributionModel)
                case .meetingMinutes:
                    MeetingMinutesRootView(model: meetingMinutesModel)
                case .snsPostingAssistant:
                    SnsPostingAssistantView(model: snsPostingAssistantModel)
                case .favorites:
                    FavoriteBookmarksView(model: favoriteBookmarkModel)
                case .friends:
                    FriendExchangeRootView(model: friendExchangeModel)
                case .manual:
                    ManualListView()
                case .distributedVideos:
                    DistributedVideoListRoot(
                        model: distributedVideoModel,
                        onSelect: { destination = .distributedVideoPlayer($0) },
                    )
                case let .distributedVideoPlayer(video):
                    DistributedVideoPlayerView(
                        video: video,
                        onBackToList: {
                            destination = .distributedVideos
                        }
                    )
                }
            }
        }
    }
}

private struct DistributedVideoListRoot: View {
    @ObservedObject var model: DistributedVideoFeatureModel
    let onSelect: (DistributedVideo) -> Void

    var body: some View {
        Group {
            if model.isLoading && model.videos.isEmpty {
                LoadingState()
            } else if let message = model.errorMessage, model.videos.isEmpty {
                ErrorState(message: message) {
                    Task {
                        await model.load()
                    }
                }
            } else if model.videos.isEmpty {
                EmptyState("配信動画はまだありません", systemImage: "play.rectangle")
            } else {
                List {
                    ForEach(model.videos) { video in
                        Button {
                            onSelect(video)
                        } label: {
                            DistributedVideoCell(video: video)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("配信動画")
        .task {
            await model.load()
        }
    }
}

private struct DistributedVideoPlayerView: View {
    let video: DistributedVideo
    let onBackToList: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    onBackToList()
                } label: {
                    Label("一覧へ戻る", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch distributedVideoSource(for: video) {
            case .embedHtml(let value):
                DistributedVideoWebView(html: value, url: nil)
            case .url(let value):
                DistributedVideoWebView(html: nil, url: value)
            case .none:
                EmptyState("この動画に再生情報がありません。", systemImage: "video.slash")
            }
        }
        .navigationTitle(video.title)
        .ignoresSafeArea()
    }
}

private struct DistributedVideoWebView: UIViewRepresentable {
    let html: String?
    let url: String?

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let html {
            webView.loadHTMLString(html, baseURL: URL(string: "https://player.vimeo.com"))
            return
        }
        guard let url, let link = URL(string: url) else {
            webView.stopLoading()
            return
        }
        webView.load(.init(url: link))
    }
}

internal enum DistributedVideoPlayerSource {
    case embedHtml(String)
    case url(String)
}

internal func distributedVideoSource(for video: DistributedVideo) -> DistributedVideoPlayerSource? {
    if !video.embedHtml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .embedHtml(video.embedHtml)
    }
    if !video.vimeoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .url(video.vimeoUrl)
    }
    if !video.videoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .url(video.videoUrl)
    }
    return nil
}

private struct DistributedVideoCell: View {
    let video: DistributedVideo

    var body: some View {
        HStack(spacing: 12) {
            if let thumbnail = URL(string: video.thumbnailUrl) {
                AsyncImage(url: thumbnail) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.secondary.opacity(0.2)
                }
                .frame(width: 96, height: 54)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 96, height: 54)
                    .overlay {
                        Image(systemName: "play.rectangle")
                            .foregroundStyle(.white.opacity(0.6))
                    }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(video.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if video.isMembersOnly {
                    Text("メンバー限定")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}
private struct FriendExchangeRootView: View {
    @ObservedObject var model: FriendExchangeFeatureModel
    @State private var editingContact: FriendContact?
    @State private var createsContact = false

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.contacts.isEmpty {
                    LoadingState()
                } else if model.contacts.isEmpty {
                    EmptyState(
                        "友達情報はまだありません",
                        systemImage: "person.crop.circle.badge.plus"
                    )
                } else {
                    List(model.contacts) { contact in
                        NavigationLink {
                            FriendContactDetailView(model: model, contact: contact)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.name).font(.headline)
                                if !contact.phoneNumber.isEmpty {
                                    Text(contact.phoneNumber).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button("編集") { editingContact = contact }
                        }
                    }
                }
            }
            .navigationTitle("友達情報・交流履歴帳")
            .toolbar {
                Button {
                    createsContact = true
                } label: {
                    Label("友達を追加", systemImage: "plus")
                }
            }
            .task { await model.loadContacts() }
            .sheet(isPresented: $createsContact) {
                FriendContactEditor(model: model, contact: nil)
            }
            .sheet(item: $editingContact) { contact in
                FriendContactEditor(model: model, contact: contact)
            }
            .alert(
                "エラー",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.clearError() } }
                )
            ) {
                Button("OK") { model.clearError() }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }
}

private struct FriendContactEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: FriendExchangeFeatureModel
    let contact: FriendContact?
    @State private var name: String
    @State private var postalCode: String
    @State private var prefecture: String
    @State private var city: String
    @State private var addressLine: String
    @State private var hasBirthDate: Bool
    @State private var birthDate: Date
    @State private var phoneNumber: String
    @State private var email: String

    init(model: FriendExchangeFeatureModel, contact: FriendContact?) {
        self.model = model
        self.contact = contact
        _name = State(initialValue: contact?.name ?? "")
        _postalCode = State(initialValue: contact?.postalCode ?? "")
        _prefecture = State(initialValue: contact?.prefecture ?? "")
        _city = State(initialValue: contact?.city ?? "")
        _addressLine = State(initialValue: contact?.addressLine ?? "")
        _hasBirthDate = State(initialValue: contact?.birthDate != nil)
        _birthDate = State(initialValue: contact?.birthDate ?? .now)
        _phoneNumber = State(initialValue: contact?.phoneNumber ?? "")
        _email = State(initialValue: contact?.email ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("名前（必須）", text: $name)
                TextField("郵便番号", text: $postalCode)
                TextField("都道府県", text: $prefecture)
                TextField("市区町村", text: $city)
                TextField("番地・建物名", text: $addressLine)
                Toggle("生年月日を登録", isOn: $hasBirthDate)
                if hasBirthDate {
                    DatePicker("生年月日", selection: $birthDate, displayedComponents: .date)
                }
                TextField("電話番号", text: $phoneNumber)
                    .keyboardType(.phonePad)
                TextField("メールアドレス", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            .navigationTitle(contact == nil ? "友達を追加" : "友達を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            let now = Date()
                            let value = FriendContact(
                                id: contact?.id ?? UUID(),
                                userId: contact?.userId ?? "guest-local",
                                name: name,
                                postalCode: postalCode,
                                prefecture: prefecture,
                                city: city,
                                addressLine: addressLine,
                                birthDate: hasBirthDate ? birthDate : nil,
                                phoneNumber: phoneNumber,
                                email: email,
                                createdAt: contact?.createdAt ?? now,
                                updatedAt: now
                            )
                            if await model.saveContact(value) { dismiss() }
                        }
                    }
                }
            }
        }
    }
}

private struct FriendContactDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject var model: FriendExchangeFeatureModel
    let contact: FriendContact
    @State private var createsHistory = false
    @State private var editingHistory: FriendInteractionHistory?
    @State private var confirmsDelete = false
    @State private var confirmsCall = false

    private var histories: [FriendInteractionHistory] {
        model.histories[contact.id] ?? []
    }

    var body: some View {
        List {
            Section("友達情報") {
                LabeledContent("名前", value: contact.name)
                if !contact.phoneNumber.isEmpty {
                    LabeledContent("電話", value: contact.phoneNumber)
                    Button("電話をかける") { confirmsCall = true }
                }
                if !contact.email.isEmpty { LabeledContent("メール", value: contact.email) }
                let address = [contact.postalCode, contact.prefecture, contact.city, contact.addressLine]
                    .filter { !$0.isEmpty }.joined(separator: " ")
                if !address.isEmpty { LabeledContent("住所", value: address) }
                if let birthDate = contact.birthDate {
                    LabeledContent("生年月日", value: birthDate.formatted(date: .numeric, time: .omitted))
                }
            }
            Section {
                Button("交流履歴を追加") { createsHistory = true }
                if histories.isEmpty {
                    Text("交流履歴はまだありません").foregroundStyle(.secondary)
                } else {
                    ForEach(histories) { history in
                        Button {
                            editingHistory = history
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(history.interactionDate.formatted(date: .abbreviated, time: .shortened))
                                Text(history.memo.isEmpty ? (history.isPhoneCall ? "電話" : "写真") : history.memo)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            } header: {
                Text("交流履歴")
            }
            Section {
                Button("この友達情報を削除", role: .destructive) { confirmsDelete = true }
            }
        }
        .navigationTitle(contact.name)
        .task { await model.loadHistories(friendId: contact.id) }
        .sheet(isPresented: $createsHistory) {
            FriendHistoryEditor(model: model, contact: contact, history: nil)
        }
        .sheet(item: $editingHistory) { history in
            FriendHistoryEditor(model: model, contact: contact, history: history)
        }
        .confirmationDialog("友達情報とすべての交流履歴を削除しますか？", isPresented: $confirmsDelete) {
            Button("削除", role: .destructive) {
                Task {
                    await model.deleteContact(contact)
                    dismiss()
                }
            }
        }
        .confirmationDialog("\(contact.phoneNumber) に電話をかけますか？", isPresented: $confirmsCall) {
            Button("電話をかける") {
                let digits = contact.phoneNumber.filter { $0.isNumber || $0 == "+" }
                if let url = URL(string: "tel:\(digits)") { openURL(url) }
            }
        }
    }
}

private struct FriendHistoryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: FriendExchangeFeatureModel
    let contact: FriendContact
    let history: FriendInteractionHistory?
    @State private var interactionDate: Date
    @State private var memo: String
    @State private var firstPhotoURL: String
    @State private var secondPhotoURL: String
    @State private var isPhoneCall: Bool
    @State private var phoneNumber: String
    @State private var confirmsDelete = false

    init(
        model: FriendExchangeFeatureModel,
        contact: FriendContact,
        history: FriendInteractionHistory?
    ) {
        self.model = model
        self.contact = contact
        self.history = history
        _interactionDate = State(initialValue: history?.interactionDate ?? .now)
        _memo = State(initialValue: history?.memo ?? "")
        _firstPhotoURL = State(initialValue: history?.photoUrls.first ?? "")
        _secondPhotoURL = State(initialValue: history?.photoUrls.dropFirst().first ?? "")
        _isPhoneCall = State(initialValue: history?.isPhoneCall ?? false)
        _phoneNumber = State(initialValue: history?.phoneNumber ?? contact.phoneNumber)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("交流日時", selection: $interactionDate)
                TextField("メモ", text: $memo, axis: .vertical)
                    .lineLimit(4...10)
                TextField("写真URL 1", text: $firstPhotoURL)
                    .textInputAutocapitalization(.never)
                TextField("写真URL 2", text: $secondPhotoURL)
                    .textInputAutocapitalization(.never)
                Toggle("電話での交流", isOn: $isPhoneCall)
                if isPhoneCall {
                    TextField("電話番号", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
                if history != nil {
                    Button("この履歴を削除", role: .destructive) { confirmsDelete = true }
                }

            }

            .navigationTitle(history == nil ? "交流履歴を追加" : "交流履歴を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            let now = Date()
                            let value = FriendInteractionHistory(
                                id: history?.id ?? UUID(),
                                friendId: contact.id,
                                interactionDate: interactionDate,
                                memo: memo,
                                photoUrls: [firstPhotoURL, secondPhotoURL].filter { !$0.isEmpty },
                                isPhoneCall: isPhoneCall,
                                phoneNumber: isPhoneCall ? phoneNumber : "",
                                createdAt: history?.createdAt ?? now,
                                updatedAt: now
                            )
                            if await model.saveHistory(value) { dismiss() }
                        }
                    }
                }
            }
            .confirmationDialog("この交流履歴を削除しますか？", isPresented: $confirmsDelete) {
                Button("削除", role: .destructive) {
                    guard let history else { return }
                    Task {
                        await model.deleteHistory(history)
                        dismiss()
                    }
                }
            }
        }
    }

}
