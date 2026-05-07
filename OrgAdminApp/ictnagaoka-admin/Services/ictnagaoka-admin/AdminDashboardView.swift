//
//  AdminDashboardView.swift
//  ictnagaoka-admin
//

import SwiftUI
import FirebaseAuth
import Combine

struct AdminDashboardView: View {

    @EnvironmentObject var organizationStore: OrganizationStore

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

                    // MARK: - 予約機能
                    menuButton(title: "イベント予約管理") {
                        AdminBookingEventListView()
                            .environmentObject(organizationStore)
                    }

                    menuButton(title: "Vimeo設定") {
                        AdminVimeoSettingsView()
                            .environmentObject(organizationStore)
                    }

                    menuButton(title: "動画管理") {
                        AdminVideoManagementView()
                            .environmentObject(organizationStore)
                    }

                    logoutButton
                }
                .padding()
            }
            .navigationTitle("管理メニュー")
        }
    }

    // MARK: - Header

    private var headerSection: some View {

        VStack(spacing: 8) {

            Text("管理者メニュー")
                .font(.largeTitle.bold())

            Text("organizationId: \(organizationStore.organizationId)")
                .font(.subheadline)
                .foregroundColor(.gray)

            if let email = Auth.auth().currentUser?.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.top)
    }

    // MARK: - Menu Button

    private func menuButton<Destination: View>(
        title: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {

        NavigationLink {
            destination()
        } label: {

            Text(title)
                .font(.title3.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                .background(Color.blue)
                .cornerRadius(24)
        }
    }

    // MARK: - Logout

    private var logoutButton: some View {

        Button {

            do {
                try Auth.auth().signOut()
                print("✅ 管理者ログアウト成功")
            } catch {
                print("❌ 管理者ログアウト失敗:", error.localizedDescription)
            }

        } label: {

            Text("ログアウト")
                .font(.title3.bold())
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                .background(Color(.systemGray5))
                .cornerRadius(24)
        }
        .padding(.top, 24)
    }
}
