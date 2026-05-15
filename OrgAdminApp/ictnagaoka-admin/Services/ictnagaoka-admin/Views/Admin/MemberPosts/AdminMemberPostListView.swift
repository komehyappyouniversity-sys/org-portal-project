//
//  AdminMemberPostListView.swift
//  ictnagaoka-admin
//

import SwiftUI

struct AdminMemberPostListView: View {
    @EnvironmentObject private var organizationStore: AdminOrganizationStore
    @StateObject private var store = AdminMemberPostStore()

    var body: some View {
        List {
            if store.isLoading && store.posts.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("会員投稿を読み込んでいます...")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }

            if !store.errorMessage.isEmpty {
                Section {
                    Text(store.errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }

            if !store.posts.isEmpty {
                Section("会員投稿一覧") {
                    ForEach(store.posts) { item in
                        NavigationLink {
                            AdminMemberPostDetailView(item: item, store: store)
                                .environmentObject(organizationStore)
                        } label: {
                            row(item)
                        }
                    }
                }
            } else if !store.isLoading {
                Section {
                    ContentUnavailableView(
                        "投稿はありません",
                        systemImage: "tray",
                        description: Text("会員からの投稿が届くと、ここに表示されます。")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("会員投稿一覧")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startListening()
        }
        .onChange(of: organizationStore.organization.id) { _ in
            startListening()
        }
    }

    private func startListening() {
        let organizationId = organizationStore.organization.id
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !organizationId.isEmpty else {
            store.errorMessage = "organizationId が空です。組織コードで接続してください。"
            return
        }

        print("📩 AdminMemberPostListView startListening organizationId:", organizationId)

        store.startListeningPosts(organizationId: organizationId)
    }

    private func row(_ item: AdminMemberPostItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title.isEmpty ? "タイトルなし" : item.title)
                        .font(.headline)
                        .lineLimit(2)

                    if !item.body.isEmpty {
                        Text(item.body)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    if !item.memberName.isEmpty {
                        Text("投稿者: \(item.memberName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if !item.memberUid.isEmpty {
                        Text("投稿者UID: \(item.memberUid)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    statusBadge(item.status)

                    if item.replyCount > 0 {
                        Text("返信 \(item.replyCount)件")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }

                    if item.memberHasReadReply == false && item.replyCount > 0 {
                        Text("会員未読")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 12) {
                if let createdAt = item.createdAt {
                    Text(dateTimeText(createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let updatedAt = item.updatedAt {
                    Text("更新: \(dateTimeText(updatedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func statusBadge(_ status: String) -> some View {
        Text(statusText(status))
            .font(.caption.bold())
            .foregroundColor(statusTextColor(status))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusBackgroundColor(status))
            .clipShape(Capsule())
    }

    private func statusText(_ status: String) -> String {
        switch status {
        case "new": return "新着"
        case "in_progress": return "対応中"
        case "resolved": return "解決"
        case "closed": return "終了"
        default: return status
        }
    }

    private func statusTextColor(_ status: String) -> Color {
        switch status {
        case "new": return .orange
        case "in_progress": return .blue
        case "resolved": return .green
        case "closed": return .secondary
        default: return .secondary
        }
    }

    private func statusBackgroundColor(_ status: String) -> Color {
        switch status {
        case "new": return Color.orange.opacity(0.15)
        case "in_progress": return Color.blue.opacity(0.15)
        case "resolved": return Color.green.opacity(0.15)
        case "closed": return Color.gray.opacity(0.15)
        default: return Color.gray.opacity(0.12)
        }
    }

    private func dateTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
