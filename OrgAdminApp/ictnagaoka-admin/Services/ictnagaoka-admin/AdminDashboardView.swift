import SwiftUI
import FirebaseAuth

struct AdminDashboardView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @EnvironmentObject var authStore: AdminAuthStore

    private var currentEmail: String {
        Auth.auth().currentUser?.email ?? "メール不明"
    }

    private var currentUid: String {
        Auth.auth().currentUser?.uid ?? "UID不明"
    }

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

                    logoutButton
                }
                .padding()
            }
            .navigationTitle("管理ダッシュボード")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ログイン中")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(currentEmail)
                .font(.headline)

            Text("UID: \(currentUid)")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Text("組織ID: \(organizationStore.organization.id)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.08))
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

    private var logoutButton: some View {
        Button {
            authStore.signOut()
        } label: {
            Text("ログアウト")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
}
