import SwiftUI

struct MemberHomeView: View {
    @EnvironmentObject private var memberStore: MemberStore
    @EnvironmentObject private var organizationStore: OrganizationStore
    @EnvironmentObject private var securityStore: MemberSecurityStore

    private var isAlreadyRegistered: Bool {
        memberStore.profile != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    VStack(spacing: 16) {
                        NavigationLink {
                            MemberMessageListView(
                                titleText: "お知らせ",
                                visibility: "public"
                            )
                            .environmentObject(memberStore)
                            .environmentObject(organizationStore)
                        } label: {
                            menuButton(
                                title: "お知らせ",
                                subtitle: "未会員の方も見ることができます",
                                systemImage: "megaphone.fill",
                                color: .orange
                            )
                        }

                        NavigationLink {
                            MemberVideoListView()
                                .environmentObject(memberStore)
                                .environmentObject(organizationStore)
                        } label: {
                            menuButton(
                                title: "動画コンテンツ",
                                subtitle: "公開中の動画を見ることができます",
                                systemImage: "play.rectangle.fill",
                                color: .purple
                            )
                        }

                        if isAlreadyRegistered {
                            menuButton(
                                title: "会員登録",
                                subtitle: "登録済みのため申請は不要です",
                                systemImage: "person.badge.plus.fill",
                                color: .green
                            )
                            .opacity(0.35)
                        } else {
                            NavigationLink {
                                MemberRegistrationView()
                                    .environmentObject(memberStore)
                                    .environmentObject(organizationStore)
                                    .environmentObject(securityStore)
                            } label: {
                                menuButton(
                                    title: "会員登録",
                                    subtitle: "新規会員申請はこちら",
                                    systemImage: "person.badge.plus.fill",
                                    color: .green
                                )
                            }
                        }

                        if isAlreadyRegistered {
                            NavigationLink {
                                MemberAreaGateView()
                                    .environmentObject(memberStore)
                                    .environmentObject(organizationStore)
                                    .environmentObject(securityStore)
                            } label: {
                                menuButton(
                                    title: "会員ページへ",
                                    subtitle: "登録済み会員メニューを開く",
                                    systemImage: "lock.fill",
                                    color: .blue
                                )
                            }
                        } else {
                            NavigationLink {
                                MemberLoginView()
                                    .environmentObject(memberStore)
                                    .environmentObject(organizationStore)
                                    .environmentObject(securityStore)
                            } label: {
                                menuButton(
                                    title: "登録済みの方はこちら",
                                    subtitle: "メールアドレスとパスワードでログイン",
                                    systemImage: "lock.fill",
                                    color: .blue
                                )
                            }
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("ホーム")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("生命の貯蓄体操")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("長岡支部")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("お知らせの確認、動画の閲覧、会員登録、登録済み会員のログインができます。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    private func menuButton(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(18)
    }
}
