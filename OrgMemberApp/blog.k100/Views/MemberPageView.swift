import SwiftUI
import FirebaseAuth

struct MemberPageView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var securityStore: MemberSecurityStore
    @EnvironmentObject private var memberStore: MemberStore
    @EnvironmentObject private var organizationStore: OrganizationStore
    @EnvironmentObject private var featureStore: MemberFeatureStore

    @State private var showCloseAlert = false
    @State private var showFullLogoutAlert = false
    @StateObject private var postStore = MemberPostStore()
    
    private let logoDisplayHeight: CGFloat = 220
    private let menuColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {

        if memberStore.isLoading {

            ProgressView("会員情報を確認しています")
                .navigationTitle("会員ページ")

        } else if memberStore.profile?.isApproved == true {

            ScrollView {

                VStack(spacing: 24) {
                    announcementSection
                    headerCard
                    organizationHeader
                    menuSection
                    settingsSection
                    logoutSection
                }
                .padding(20)
            }
            .navigationTitle("会員ページ")
            .navigationBarTitleDisplayMode(.inline)
            .alert("会員ページを閉じますか？", isPresented: $showCloseAlert) {

                Button("キャンセル", role: .cancel) { }

                Button("閉じる", role: .destructive) {
                    closeMemberPage()
                }

            } message: {
                Text("Face ID認証画面に戻ります。メールアドレスとパスワードは保存されたままです。")
            }
            .alert("完全ログアウトしますか？", isPresented: $showFullLogoutAlert) {

                Button("キャンセル", role: .cancel) { }

                Button("完全ログアウト", role: .destructive) {
                    fullLogout()
                }

            } message: {
                Text("保存されたログイン情報を削除し、次回はメールアドレスとパスワードの入力が必要になります。")
            }
            
                
            .onAppear {
                startPostListeningIfPossible()
            }
            .onDisappear {
                postStore.stopListening()
            }

        } else {

            VStack(spacing: 24) {

                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 72))
                    .foregroundColor(.orange)

                Text("管理者の承認待ちです")
                    .font(.title2.bold())

                Text("会員ページは、管理者が会員申請を承認した後に利用できます。")
                    .multilineTextAlignment(.center)

                Button("閉じる") {
                    closeMemberPage()
                }
                
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("会員認証")
        }
    }

    @ViewBuilder
    private var announcementSection: some View {
        if featureStore.settings.memberMessageEnabled {

            NavigationLink {
                MemberMessageListView(
                    titleText: "お知らせ",
                    visibility: "member"
                )
                .environmentObject(memberStore)
                .environmentObject(organizationStore)

            } label: {
                topActionButton(
                    title: "お知らせ",
                    subtitle: "大切な連絡を見る",
                    systemImage: "bell.fill",
                    color: .orange
                )
            }
        }
    }

    private var organizationHeader: some View {
        VStack(spacing: 12) {

            if let url = URL(string: organizationStore.logoImageURL),
               !organizationStore.logoImageURL
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty {

                AsyncImage(url: url) { phase in
                    switch phase {

                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: logoDisplayHeight)

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: logoDisplayHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 20))

                    case .failure:
                        Image(systemName: "building.2.crop.circle")
                            .font(.system(size: 120))
                            .foregroundColor(.gray)

                    @unknown default:
                        EmptyView()
                    }
                }

            } else {

                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 120))
                    .foregroundColor(.gray)
            }

            Text(organizationName)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("会員情報")
                .font(.headline)

            infoRow(title: "お名前", value: profileName)

            infoRow(title: "会員状態", value: profileStatusText)

            infoRow(title: "UID", value: authUID)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: 18) {

            LazyVGrid(columns: menuColumns, spacing: 14) {

                if featureStore.videoEnabled {

                    NavigationLink {
                        MemberVideoListView()
                            .environmentObject(memberStore)
                            .environmentObject(organizationStore)

                    } label: {
                        largeMenuButton(
                            title: "動画",
                            systemImage: "play.rectangle.fill",
                            color: .blue
                        )
                    }
                }

                if featureStore.bookingEnabled {

                    NavigationLink {
                        MemberBookingEventListView(
                            organizationId: organizationStore.organizationId
                        )
                        .environmentObject(memberStore)
                        .environmentObject(organizationStore)

                    } label: {
                        largeMenuButton(
                            title: "予約",
                            systemImage: "calendar.badge.plus",
                            color: .green
                        )
                    }
                }

                if featureStore.settings.memberPostEnabled {

                    NavigationLink {
                        MemberPostView()
                            .environmentObject(memberStore)
                            .environmentObject(organizationStore)

                    } label: {
                        largeMenuButton(
                            title: "投稿",
                            systemImage: "square.and.pencil",
                            color: .purple
                        )
                    }
                }
            }

            LazyVGrid(columns: menuColumns, spacing: 14) {

                if featureStore.settings.scheduleEnabled {

                    NavigationLink {
                        ScheduleView()
                            .environmentObject(memberStore)
                            .environmentObject(organizationStore)

                    } label: {
                        gridMenuButton(
                            title: "スケジュール",
                            systemImage: "calendar",
                            color: .teal
                        )
                    }
                }

                NavigationLink {
                    TodayScheduleView()
                } label: {
                    gridMenuButton(
                        title: "今日の予定",
                        systemImage: "sun.max.fill",
                        color: .yellow
                    )
                }

                NavigationLink {
                    MemberDiaryListView(
                        organizationId: organizationStore.organizationId
                    )
                } label: {
                    gridMenuButton(
                        title: "日記",
                        systemImage: "book.closed.fill",
                        color: .indigo
                    )
                }

                NavigationLink {
                    SNSPostMenuView()
                } label: {
                    gridMenuButton(
                        title: "SNSに投稿",
                        systemImage: "square.and.arrow.up.fill",
                        color: .pink
                    )
                }

                if featureStore.videoEnabled {

                    NavigationLink {
                        MemberVideoQuestionListView()
                            .environmentObject(memberStore)
                            .environmentObject(organizationStore)

                    } label: {
                        gridMenuButton(
                            title: "動画質問・回答",
                            systemImage: "questionmark.bubble.fill",
                            color: .cyan
                        )
                    }
                }

                if featureStore.settings.memberPostEnabled {

                    NavigationLink {
                        MemberPostHistoryView()
                            .environmentObject(memberStore)
                            .environmentObject(organizationStore)

                    } label: {

                        ZStack(alignment: .topTrailing) {

                            gridMenuButton(
                                title: "投稿履歴",
                                systemImage: "tray.full.fill",
                                color: .brown
                            )

                            if unreadReplyCount > 0 {
                                unreadBadge
                            }
                        }
                    }
                }
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            NavigationLink {
                SecuritySettingsView()
            } label: {
                settingsButton(
                    title: "セキュリティ設定",
                    systemImage: "lock.shield.fill"
                )
            }
        }
        .padding(.top, 6)
    }

private var logoutSection: some View {

    VStack(spacing: 12) {

        Button {

            showCloseAlert = true

        } label: {

            settingsButton(
                title: "会員ページを閉じる",
                systemImage: "xmark.circle.fill",
                foregroundColor: .red,
                backgroundColor: Color(.systemGray6)
            )
        }

        Button {

            showFullLogoutAlert = true

        } label: {

            settingsButton(
                title: "完全ログアウト",
                systemImage: "rectangle.portrait.and.arrow.right",
                foregroundColor: .white,
                backgroundColor: .red
            )
        }
    }
    .padding(.top, 4)
}

    private func topActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color
    ) -> some View {

        HStack(spacing: 16) {

            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .bold))
                .frame(width: 54, height: 54)
                .background(Color.white.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                    .lineLimit(1)

                Text(subtitle)
                    .font(.headline)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline.bold())
        }
        .foregroundColor(.white)
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func largeMenuButton(
        title: String,
        systemImage: String,
        color: Color
    ) -> some View {

        VStack(spacing: 12) {

            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .bold))

            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 124)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func gridMenuButton(
        title: String,
        systemImage: String,
        color: Color
    ) -> some View {

        VStack(spacing: 10) {

            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))

            Text(title)
                .font(.headline.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func settingsButton(
        title: String,
        systemImage: String,
        foregroundColor: Color = .primary,
        backgroundColor: Color = Color(.secondarySystemBackground)
    ) -> some View {

        HStack(spacing: 12) {

            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 30)

            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer()
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var unreadBadge: some View {
        Text("\(unreadReplyCount)")
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red)
            .clipShape(Capsule())
            .offset(x: -10, y: 8)
    }

    private var organizationName: String {

        let displayName = organizationStore.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !displayName.isEmpty {
            return displayName
        }

        let code = organizationStore.organizationCode
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !code.isEmpty {
            return code
        }

        return "組織名未設定"
    }

    private var profileName: String {

        if let name = memberStore.profile?.name
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {

            return name
        }

        return "未設定"
    }

    private var profileStatusText: String {

        let status = memberStore.profile?.status ?? ""

        switch status {

        case "approved":
            return "承認済み"

        case "pending":
            return "申請中"

        case "rejected":
            return "差し戻し"

        default:
            return status.isEmpty ? "未確認" : status
        }
    }

    private var authUID: String {

        let uid = memberStore.authUid?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return uid.isEmpty ? "未取得" : uid
    }

    private var unreadReplyCount: Int {
        postStore.posts.filter { $0.hasUnreadReply }.count
    }

    private func infoRow(title: String, value: String) -> some View {

        VStack(alignment: .leading, spacing: 4) {

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.body)
                .foregroundColor(.primary)
        }
    }

    private func menuButton(title: String) -> some View {

        Text(title)
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.blue)
            .cornerRadius(14)
    }

    private func startPostListeningIfPossible() {
        
        guard memberStore.profile?.isApproved == true else {
            return
        }

        let organizationId = organizationStore.organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let memberUid = memberStore.authUid?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !organizationId.isEmpty,
              !memberUid.isEmpty else {
            return
        }

        postStore.startListening(
            organizationId: organizationId,
            memberUid: memberUid
        )
    }

private func closeMemberPage() {

    securityStore.lockNow()
}

private func fullLogout() {

    MemberSavedLoginStore.shared.clear()

    do {
        try Auth.auth().signOut()
    } catch {
        print("❌ 完全ログアウト失敗:", error.localizedDescription)
    }

    securityStore.lockNow()
}
}
