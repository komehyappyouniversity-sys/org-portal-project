//
//  MemberPageView.swift
//  ictnagaoka
//

import SwiftUI
import FirebaseAuth

struct MemberPageView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var securityStore: MemberSecurityStore
    @EnvironmentObject private var memberStore: MemberStore
    @EnvironmentObject private var organizationStore: OrganizationStore

    @State private var showLogoutAlert = false
    @StateObject private var postStore = MemberPostStore()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerCard
                menuSection
                logoutSection
            }
            .padding(20)
        }
        .navigationTitle("会員ページ")
        .navigationBarTitleDisplayMode(.inline)
        .alert("ログアウトしますか？", isPresented: $showLogoutAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("ログアウト", role: .destructive) {
                logout()
            }
        } message: {
            Text("この端末の会員ページ認証を解除します。")
        }
        .onAppear {
            startPostListeningIfPossible()
        }
        .onDisappear {
            postStore.stopListening()
        }
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

            NavigationLink {
                ScheduleView()
                    .environmentObject(memberStore)
                    .environmentObject(organizationStore)
            } label: {
                menuButton(title: "スケジュール")
            }

            NavigationLink {
                MemberBookingEventListView(
                    organizationId: organizationStore.organization.id
                )
                .environmentObject(memberStore)
                .environmentObject(organizationStore)
            } label: {
                menuButton(title: "講座予約")
            }

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

            NavigationLink {
                MemberVideoListView()
                    .environmentObject(memberStore)
                    .environmentObject(organizationStore)
            } label: {
                menuButton(title: "動画コンテンツ")
            }

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

    private var logoutSection: some View {
        Button {
            showLogoutAlert = true
        } label: {
            Text("会員ページを閉じる")
                .font(.headline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(.systemGray6))
                .cornerRadius(14)
        }
        .padding(.top, 8)
    }

    private var profileName: String {
        if let name = memberStore.profile?.name.trimmingCharacters(in: .whitespacesAndNewlines),
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
        let uid = memberStore.authUid?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
        let organizationId = organizationStore.organization.id
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let memberUid = memberStore.authUid?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !organizationId.isEmpty, !memberUid.isEmpty else { return }

        postStore.startListening(
            organizationId: organizationId,
            memberUid: memberUid
        )
    }

    private func logout() {
        securityStore.isUnlocked = false
        dismiss()
    }
}
