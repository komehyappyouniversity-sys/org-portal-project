import SwiftUI
import FirebaseAuth

struct AdminDashboardView: View {

    @EnvironmentObject var organizationStore: OrganizationStore
    @EnvironmentObject var authStore: AdminAuthStore
    @EnvironmentObject var featureStore: AdminFeatureStore

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(spacing: 16) {

                    headerSection

                    // 公開お知らせ
                    if featureStore.announcementEnabled {

                        menuButton(title: "公開お知らせ送信") {

                            AdminAnnouncementComposerView()
                                .environmentObject(organizationStore)
                        }
                    }

                    // 一斉送信
                    if featureStore.messageEnabled {

                        menuButton(title: "会員へ一斉送信") {

                            AdminMessageComposerView()
                                .environmentObject(organizationStore)
                        }
                    }

                    // 送信済み一覧
                    if featureStore.messageEnabled
                        || featureStore.announcementEnabled {

                        menuButton(title: "送信済み一覧") {

                            AdminSentMessageListView()
                                .environmentObject(organizationStore)
                        }
                    }

                    // 会員申請一覧
                    menuButton(title: "会員申請一覧") {

                        AdminRequestsListView()
                            .environmentObject(organizationStore)
                    }

                    // 会員一覧
                    menuButton(title: "会員一覧") {

                        AdminMemberListView()
                            .environmentObject(organizationStore)
                    }

                    // 会員投稿一覧
                    if featureStore.memberPostEnabled {

                        menuButton(title: "会員投稿一覧") {

                            AdminMemberPostListView()
                                .environmentObject(organizationStore)
                        }
                    }

                    // カテゴリ管理
                    if featureStore.categoryEnabled {

                        menuButton(title: "カテゴリ管理") {

                            AdminCategorySettingsView()
                                .environmentObject(organizationStore)
                        }
                    }

                    // 予約管理
                    if featureStore.bookingEnabled {

                        menuButton(title: "予約管理") {

                            AdminBookingEventListView()
                                .environmentObject(organizationStore)
                        }
                    }

                    // 動画管理
                    if featureStore.videoEnabled {

                        menuButton(title: "動画管理") {

                            AdminVideoManagementView()
                                .environmentObject(organizationStore)
                        }
                    }

                    // 有料動画
                    if featureStore.paidVideoEnabled {

                        menuButton(title: "有料動画・課金設定") {

                            AdminVideoManagementView()
                                .environmentObject(organizationStore)
                        }
                    }

                    // 読み込み中
                    if featureStore.isLoading {

                        ProgressView("機能設定を読み込み中...")
                            .padding(.top, 8)
                    }

                    // エラー表示
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

            .onAppear {

                let organizationId =
                organizationStore.organization.id
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let resolvedOrganizationId =
                organizationId.isEmpty
                ? OrganizationConfig.organizationId
                : organizationId

                print("[DEBUG] 機能監視 organizationId:",
                      resolvedOrganizationId)

                guard !resolvedOrganizationId.isEmpty else {

                    print("[ERROR] organizationId が空です。")
                    return
                }

                featureStore.startListening(
                    organizationId: resolvedOrganizationId
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {

        VStack(spacing: 8) {

            Text("管理アプリ")
                .font(.largeTitle.bold())

            Text(
                "organizationId: \(organizationStore.organization.id.isEmpty ? OrganizationConfig.organizationId : organizationStore.organization.id)"
            )
            .font(.caption)
            .foregroundColor(.gray)
        }
        .padding(.bottom, 8)
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
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .cornerRadius(12)
        }
    }
}
