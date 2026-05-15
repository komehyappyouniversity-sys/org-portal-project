import SwiftUI
import FirebaseAuth

struct AdminDashboardView: View {

    @EnvironmentObject var organizationStore: AdminOrganizationStore
    @EnvironmentObject var authStore: AdminAuthStore
    @EnvironmentObject var featureStore: AdminFeatureStore

    private var resolvedOrganizationId: String {
        let id = organizationStore.organization.id
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return id.isEmpty ? OrganizationConfig.organizationId : id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    headerSection

                    if featureStore.announcementEnabled {
                        menuButton(title: "公開お知らせ送信") {
                            AdminAnnouncementComposerView()
                                .environmentObject(organizationStore)
                        }
                    }

                    if featureStore.messageEnabled {
                        menuButton(title: "会員へ一斉送信") {
                            AdminMessageComposerView()
                                .environmentObject(organizationStore)
                        }
                    }

                    if featureStore.messageEnabled || featureStore.announcementEnabled {
                        menuButton(title: "送信済み一覧") {
                            AdminSentMessageListView()
                                .environmentObject(organizationStore)
                        }
                    }

                    menuButton(title: "会員申請一覧") {
                        AdminRequestsListView()
                            .environmentObject(organizationStore)
                    }

                    menuButton(title: "会員一覧") {
                        AdminMemberListView()
                            .environmentObject(organizationStore)
                    }

                    if featureStore.memberPostEnabled {
                        menuButton(title: "会員投稿一覧") {
                            AdminMemberPostListView()
                                .environmentObject(organizationStore)
                        }
                    }

                    if featureStore.categoryEnabled {
                        menuButton(title: "カテゴリ管理") {
                            AdminCategorySettingsView()
                                .environmentObject(organizationStore)
                        }
                    }

                    if featureStore.bookingEnabled {
                        menuButton(title: "予約管理") {
                            AdminBookingEventListView()
                                .environmentObject(organizationStore)
                        }
                    }

                    if featureStore.videoEnabled {
                        menuButton(title: "Vimeo連携設定") {
                            AdminVimeoSettingsView()
                                .environmentObject(organizationStore)
                        }

                        menuButton(title: "動画管理") {
                            AdminVideoManagementView()
                                .environmentObject(organizationStore)
                        }
                    }

                    if featureStore.paidVideoEnabled {
                        menuButton(title: "有料動画・課金設定") {
                            AdminSubscriptionManageView()
                                .environmentObject(organizationStore)
                        }
                    }

                    if featureStore.isLoading {
                        ProgressView("機能設定を読み込み中...")
                            .padding(.top, 8)
                    }

                    if !featureStore.errorMessage.isEmpty {
                        Text(featureStore.errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
            .navigationTitle("管理メニュー")
            
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("管理アプリ")
                .font(.largeTitle.bold())

            Text("organizationId: \(resolvedOrganizationId)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.bottom, 8)
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
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .cornerRadius(12)
        }
    }
}
