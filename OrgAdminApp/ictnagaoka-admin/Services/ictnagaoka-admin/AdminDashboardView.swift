import SwiftUI
import FirebaseAuth

struct AdminDashboardView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @EnvironmentObject var authStore: AdminAuthStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    headerSection

                    menuButton(title: "公開お知らせ送信") {
                        AdminAnnouncementComposerView()
                            .environmentObject(organizationStore)
                    }

                    menuButton(title: "会員へ一斉送信") {
                        AdminMessageComposerView()
                            .environmentObject(organizationStore)
                    }

                    menuButton(title: "送信済み一覧") {
                        AdminSentMessageListView()
                            .environmentObject(organizationStore)
                    }

                    menuButton(title: "会員申請一覧") {
                        AdminRequestsListView()
                            .environmentObject(organizationStore)
                    }

                    menuButton(title: "会員一覧") {
                        AdminMemberListView()
                            .environmentObject(organizationStore)
                    }

                    menuButton(title: "会員投稿一覧") {
                        AdminMemberPostListView()
                            .environmentObject(organizationStore)
                    }

                    menuButton(title: "カテゴリ管理") {
                        AdminCategorySettingsView()
                            .environmentObject(organizationStore)
                    }

                    menuButton(title: "Vimeo連携設定") {
                        AdminVimeoSettingsView()
                            .environmentObject(organizationStore)
                    }

                    Button {
                        authStore.signOut()
                    } label: {
                        Text("ログアウト")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle("管理メニュー")
            .onAppear {
                if organizationStore.organizationId.isEmpty {
                    organizationStore.startListening(
                        organizationId: OrganizationConfig.organizationId
                    )
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("管理アプリ")
                .font(.largeTitle.bold())

            Text("organizationId: \(organizationStore.organizationId.isEmpty ? OrganizationConfig.organizationId : organizationStore.organizationId)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let email = Auth.auth().currentUser?.email {
                Text(email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 12)
    }

    private func menuButton<Destination: View>(
        title: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
        }
    }
}
