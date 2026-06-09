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

    var body: some View {

        if memberStore.isLoading {

            ProgressView("会員情報を確認しています")
                .navigationTitle("会員ページ")

        } else if memberStore.profile?.isApproved == true {

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
            
            NavigationLink {
                TodayScheduleView()
            } label: {
                menuButton(title: "今日の予定")
            }
            
            NavigationLink {
                MemberDiaryListView(
                    organizationId: organizationStore.organizationId
                )
            } label: {
                menuButton(title: "日記")
            }

            NavigationLink {
                SNSPostMenuView()
            } label: {
                menuButton(title: "SNSに投稿")
            }
            
            NavigationLink {
                SecuritySettingsView()
            } label: {
                menuButton(title: "セキュリティ設定")
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
                NavigationLink {
                    MemberVideoQuestionListView()
                        .environmentObject(memberStore)
                        .environmentObject(organizationStore)

                } label: {
                    menuButton(title: "動画質問・回答")
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

    VStack(spacing: 12) {

        Button {

            showCloseAlert = true

        } label: {

            Text("会員ページを閉じる")
                .font(.headline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(.systemGray6))
                .cornerRadius(14)
        }

        Button {

            showFullLogoutAlert = true

        } label: {

            Text("完全ログアウト")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.red)
                .cornerRadius(14)
        }
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
