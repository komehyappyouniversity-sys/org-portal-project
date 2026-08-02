import DesignSystem
import Model
import SwiftUI

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
        case youtubeSearch
        case personalVideos
        case videoQuestions

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
            case .youtubeSearch: "youtubeSearch"
            case .personalVideos: "personalVideos"
            case .videoQuestions: "videoQuestions"
        }
    }

    @ObservedObject private var scheduleModel: ScheduleFeatureModel
    @ObservedObject private var diaryModel: DiaryFeatureModel
    @ObservedObject private var cashDistributionModel: CashDistributionFeatureModel
    @ObservedObject private var meetingMinutesModel: MeetingMinutesFeatureModel
    @ObservedObject private var snsPostingAssistantModel: SnsPostingAssistantFeatureModel
    @ObservedObject private var favoriteBookmarkModel: FavoriteBookmarkFeatureModel
    @ObservedObject private var friendExchangeModel: FriendExchangeFeatureModel
    @ObservedObject private var personalVideoModel: PersonalVideoFeatureModel
    @ObservedObject private var videoQuestionModel: VideoQuestionFeatureModel
    @State private var destination: Destination?

    public init(
        scheduleModel: ScheduleFeatureModel,
        diaryModel: DiaryFeatureModel,
        cashDistributionModel: CashDistributionFeatureModel,
        meetingMinutesModel: MeetingMinutesFeatureModel,
        snsPostingAssistantModel: SnsPostingAssistantFeatureModel,
        favoriteBookmarkModel: FavoriteBookmarkFeatureModel,
        friendExchangeModel: FriendExchangeFeatureModel,
        personalVideoModel: PersonalVideoFeatureModel,
        videoQuestionModel: VideoQuestionFeatureModel
    ) {
        self.scheduleModel = scheduleModel
        self.diaryModel = diaryModel
        self.cashDistributionModel = cashDistributionModel
        self.meetingMinutesModel = meetingMinutesModel
        self.snsPostingAssistantModel = snsPostingAssistantModel
        self.favoriteBookmarkModel = favoriteBookmarkModel
        self.friendExchangeModel = friendExchangeModel
        self.personalVideoModel = personalVideoModel
        self.videoQuestionModel = videoQuestionModel
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
                    destination = .personalVideos
                } label: {
                    FeatureCard(
                        "YouTube動画メモ",
                        subtitle: "タイトル・URL・再生位置メモを端末内で管理します。",
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
                Button {
                    destination = .youtubeSearch
                } label: {
                    FeatureCard(
                        "YouTube検索・登録",
                        subtitle: "キーワード検索からYouTubeを開き、動画URLを保存できます。",
                        systemImage: "magnifyingglass"
                    )
                }
                .buttonStyle(.plain)
                Button {
                    destination = .videoQuestions
                } label: {
                    FeatureCard(
                        "動画質問",
                        subtitle: "動画の質問を投稿し、回答を確認できます。",
                        systemImage: "bubble.left.and.bubble.right"
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
                case .youtubeSearch:
                    YoutubeSearchView()
                case .personalVideos:
                    PersonalVideosView(model: personalVideoModel)
                case .videoQuestions:
                    VideoQuestionsView(model: videoQuestionModel)
                }
            }
        }
    }
}

}

private struct YoutubeSearchView: View {
    @State private var keyword = ""
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section("YouTube検索") {
                    TextField("検索ワード", text: $keyword)
                    Button {
                        openYouTubeSearch()
                    } label: {
                        Label("YouTubeで検索", systemImage: "magnifyingglass")
                    }
                    .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("使い方") {
                    Text("検索結果から開いた動画URLを『お気に入り』画面で登録できます。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("YouTube検索・登録")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func openYouTubeSearch() {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)") else {
            return
        }
        openURL(url)
    }
}

private struct VideoQuestionsView: View {
    @ObservedObject private var model: VideoQuestionFeatureModel
    @State private var videoId = ""
    @State private var videoTitle = ""
    @State private var note = ""
    @State private var questionText = ""
    @State private var playbackSeconds = "0"

    init(model: VideoQuestionFeatureModel) {
        self.model = model
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.questions.isEmpty {
                    LoadingState()
                } else if model.questions.isEmpty {
                    VStack(spacing: 12) {
                        EmptyState("まだ質問はありません", systemImage: "bubble.left.and.exclamationmark.bubble.right")
                        Text("動画IDと質問内容を入力して送信してください。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(model.questions) { question in
                            Section {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(question.videoTitle)
                                            .font(.headline)
                                        Spacer()
                                        Text(question.status == .unanswered ? "未回答" : "回答済")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(question.questionText)
                                        .font(.body)
                                    if !question.noteText.isEmpty {
                                        Text(question.noteText)
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("回答: \(question.answerText.isEmpty ? "（まだありません）" : question.answerText)")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                            } header: {
                                Text(formatted(question.createdAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("動画質問")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("更新") {
                        Task { await model.load() }
                    }
                }
            }
            .task { await model.load() }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                TextField("動画ID（YouTube ID など）", text: $videoId)
                    .textFieldStyle(.roundedBorder)
                TextField("タイトル", text: $videoTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("メモ（任意）", text: $note)
                    .textFieldStyle(.roundedBorder)
                TextField("再生位置（秒）", text: $playbackSeconds)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                TextEditor(text: $questionText)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.4))
                    )
                if let message = model.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if model.isSaving {
                    ProgressView()
                }
                Button("送信") {
                    Task {
                        await model.sendQuestion(
                            videoId: videoId,
                            videoTitle: videoTitle,
                            noteText: note,
                            questionText: questionText,
                            playbackSecondsText: playbackSeconds
                        )
                        videoId = ""
                        videoTitle = ""
                        note = ""
                        questionText = ""
                        playbackSeconds = "0"
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.cannotSend)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .alert(
            "お知らせ",
            isPresented: Binding(
                get: { model.notice != nil },
                set: { if !$0 { model.clearNotice() } }
            )
        ) {
            Button("閉じる") { model.clearNotice() }
        } message: {
            Text(model.notice ?? "")
        }
        .alert(
            "エラー",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.clearError() } }
            )
        ) {
            Button("閉じる") { model.clearError() }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
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
