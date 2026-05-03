import SwiftUI
import FirebaseAuth

struct AdminDashboardView: View {
    @EnvironmentObject var organizationStore: OrganizationStore
    @EnvironmentObject var authStore: AdminAuthStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    menuSection
                }
                .padding(20)
            }
            .navigationTitle("管理ダッシュボード")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - ヘッダー

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("管理アプリ")
                .font(.title2.bold())

            infoRow(title: "organizationId", value: organizationStore.organization.id)

            if let user = Auth.auth().currentUser {
                infoRow(title: "ログインUID", value: user.uid)
                infoRow(title: "メール", value: user.email ?? "なし")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
        }
    }

    // MARK: - メニュー

    private var menuSection: some View {
        VStack(spacing: 16) {

            // 公開お知らせ
            NavigationLink {
                AdminAnnouncementComposerView()
                    .environmentObject(organizationStore)
            } label: {
                menuRow(
                    title: "公開お知らせ送信",
                    systemImage: "megaphone"
                )
            }
            .buttonStyle(.plain)

            // 会員へ送信
            NavigationLink {
                AdminMessageComposerView()
                    .environmentObject(organizationStore)
            } label: {
                menuRow(
                    title: "会員へ一斉送信",
                    systemImage: "paperplane"
                )
            }
            .buttonStyle(.plain)

            // 会員申請一覧
            NavigationLink {
                AdminRequestsListView()
                    .environmentObject(organizationStore)
            } label: {
                menuRow(
                    title: "会員申請一覧",
                    systemImage: "person.badge.plus"
                )
            }
            .buttonStyle(.plain)

            // 会員一覧
            NavigationLink {
                AdminMemberListView()
                    .environmentObject(organizationStore)
            } label: {
                menuRow(
                    title: "会員一覧",
                    systemImage: "person.3"
                )
            }
            .buttonStyle(.plain)

            // 投稿管理
            NavigationLink {
                AdminMemberPostListView()
                    .environmentObject(organizationStore)
            } label: {
                menuRow(
                    title: "会員投稿管理",
                    systemImage: "text.bubble"
                )
            }
            .buttonStyle(.plain)

            // 動画管理（今回エラーの原因だった部分）
            NavigationLink {
                AdminVideoManagerView()
                    .environmentObject(organizationStore)
            } label: {
                menuRow(
                    title: "動画管理",
                    systemImage: "play.rectangle"
                )
            }
            .buttonStyle(.plain)

            // ログアウト
            Button {
                try? Auth.auth().signOut()
            } label: {
                menuRow(
                    title: "ログアウト",
                    systemImage: "arrow.backward.circle"
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 共通メニューRow

    private func menuRow(
        title: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 28)

            Text(title)
                .font(.headline)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
