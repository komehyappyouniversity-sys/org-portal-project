import SwiftUI
import FirebaseAuth

struct MemberPageView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var securityStore: MemberSecurityStore
    @EnvironmentObject private var memberStore: MemberStore
    @EnvironmentObject private var organizationStore: OrganizationStore
    @EnvironmentObject private var featureStore: MemberFeatureStore

    @State private var showLogoutAlert = false
    @StateObject private var postStore = MemberPostStore()

    private let logoDisplayHeight: CGFloat = 220

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                organizationHeader
                headerCard
                menuSection
                logoutSection
            }
            .padding(20)
        }
        .navigationTitle("会員ページ")
        .navigationBarTitleDisplayMode(.inline)
        .alert("ログアウトしますか？", isPresented: $showLogoutAlert) {
            Button("キャンセル", role: .cancel) { }

            Button("ログアウト", role: .destructive) {
                logout()
            }

        } message: {
            Text("この端末の会員ページ認証を解除します。")
        }
        .onAppear {
            startPostListeningIfPossible()
        }
        .onDisappear {
            postStore.stopListening()
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
        VStack(spacing: 14) {

            if featureStore.settings.scheduleEnabled {

                NavigationLink {
                    ScheduleView()
                        .environmentObject(memberStore)
                        .environmentObject(organizationStore)

                } label: {
                    menuButton(title: "スケジュール")
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
                    menuButton(title: "講座予約")
                }
            }

            if featureStore.settings.memberMessageEnabled {

                NavigationLink {
                    MemberMessageListView(
                        titleText: "お知らせ",
                        visibility: "member"
                    )
                    .environmentObject(memberStore)
                    .environmentObject(organizationStore)

                } label: {
                    menuButton(title: "お知らせ")
                }
            }

            if featureStore.videoEnabled {

                NavigationLink {
                    MemberVideoListView()
                        .environmentObject(memberStore)
                        .environmentObject(organizationStore)

                } label: {
                    menuButton(title: "動画コンテンツ")
                }
            }

            if featureStore.settings.memberPostEnabled {

                NavigationLink {
                    MemberPostView()
                        .environmentObject(memberStore)
                        .environmentObject(organizationStore)

                } label: {
                    menuButton(title: "管理者へ投稿")
                }

                NavigationLink {
                    MemberPostHistoryView()
                        .environmentObject(memberStore)
                        .environmentObject(organizationStore)

                } label: {

                    ZStack(alignment: .topTrailing) {

                        menuButton(title: "投稿履歴")

                        if unreadReplyCount > 0 {

                            Text("\(unreadReplyCount)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .clipShape(Capsule())
                                .offset(x: -10, y: 8)
                        }
                    }
                }
            }
        }
    }

    private var logoutSection: some View {

        Button {

            showLogoutAlert = true

        } label: {

            Text("会員ページを閉じる")
                .font(.headline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(.systemGray6))
                .cornerRadius(14)
        }
        .padding(.top, 8)
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

    private func logout() {
        securityStore.isUnlocked = false
        dismiss()
    }
}
