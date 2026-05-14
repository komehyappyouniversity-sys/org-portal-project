import SwiftUI

struct MemberHomeView: View {
    @EnvironmentObject private var memberStore: MemberStore
    @EnvironmentObject private var organizationStore: OrganizationStore
    @EnvironmentObject private var securityStore: MemberSecurityStore
    @EnvironmentObject private var featureStore: MemberFeatureStore

    private var isAlreadyRegistered: Bool {
        memberStore.profile != nil
    }

    private var organizationTitle: String {
        let name = organizationStore.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return name.isEmpty ? "会員アプリ" : name
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    VStack(spacing: 16) {

                        if featureStore.settings.publicAnnouncementEnabled {
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
                        }

                        if featureStore.videoEnabled {
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
                        }

                        if isAlreadyRegistered {
                            NavigationLink {
                                MemberAreaGateView()
                                    .environmentObject(memberStore)
                                    .environmentObject(organizationStore)
                                    .environmentObject(securityStore)
                                    .environmentObject(featureStore)
                            } label: {
                                menuButton(
                                    title: "会員ページを開く",
                                    subtitle: "Face IDで認証して会員メニューを開きます",
                                    systemImage: "faceid",
                                    color: .blue
                                )
                            }
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

                    if !featureStore.errorMessage.isEmpty {
                        Text(featureStore.errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
                .padding(24)
            }
            .navigationTitle("ホーム")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            memberStore.setOrganizationId(organizationStore.organizationId)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(organizationTitle)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

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
