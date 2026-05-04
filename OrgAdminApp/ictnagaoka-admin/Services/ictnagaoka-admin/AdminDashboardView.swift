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

                    Button {
                        authStore.signOut()
                    } label: {
                        Text("ログアウト")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.top, 12)
                }
                .padding()
            }
            .navigationTitle("管理メニュー")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                organizationStore.startListening(
                    organizationId: OrganizationConfig.organizationId
                )
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("管理アプリ")
                .font(.title2.bold())

            Text("organizationId: \(OrganizationConfig.organizationId)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let email = Auth.auth().currentUser?.email {
                Text("ログイン中: \(email)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.12))
        .cornerRadius(12)
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
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
}
