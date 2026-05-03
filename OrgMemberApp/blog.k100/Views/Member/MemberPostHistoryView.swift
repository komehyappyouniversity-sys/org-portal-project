import SwiftUI

struct MemberPostHistoryView: View {
    @EnvironmentObject private var memberStore: MemberStore
    @EnvironmentObject private var organizationStore: OrganizationStore
    @StateObject private var store = MemberPostStore()

    var body: some View {
        List {
            if store.posts.isEmpty {
                VStack(spacing: 12) {
                    Text("投稿履歴はまだありません")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("管理者へ投稿すると、ここに履歴が表示されます。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)

            } else {
                ForEach(store.posts) { item in
                    NavigationLink {
                        MemberPostDetailView(
                            item: item,
                            organizationId: organizationStore.organization.id
                        )
                        .environmentObject(store)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)

                                Spacer()

                                if item.hasUnreadReply {
                                    Text("未読返信")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red)
                                        .cornerRadius(8)
                                }
                            }

                            Text(item.body)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)

                            HStack {
                                Text(formatDate(item.createdAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                if let replyBody = item.replyBody,
                                   !replyBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(item.hasUnreadReply ? "返信あり（未読）" : "返信あり")
                                        .font(.caption)
                                        .foregroundColor(item.hasUnreadReply ? .red : .blue)
                                } else {
                                    Text("返信なし")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("投稿履歴")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let organizationId = organizationStore.organization.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let memberUid = memberStore.authUid?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !organizationId.isEmpty, !memberUid.isEmpty else { return }

            store.startListening(
                organizationId: organizationId,
                memberUid: memberUid
            )
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
