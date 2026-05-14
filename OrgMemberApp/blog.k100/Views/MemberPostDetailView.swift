import SwiftUI

struct MemberPostDetailView: View {
    @EnvironmentObject private var store: MemberPostStore

    let item: MemberPostItem
    let organizationId: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                Text(item.title)
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.body)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("管理者からの返信")
                        .font(.headline)

                    if store.isLoadingReplies {
                        ProgressView("返信を読み込み中...")

                    } else if store.replies.isEmpty {
                        Text("返信はまだありません。")
                            .font(.body)
                            .foregroundColor(.secondary)

                    } else {
                        ForEach(store.replies) { reply in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(reply.createdByName.isEmpty ? "管理者" : reply.createdByName)
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Text(formatDate(reply.createdAt))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text(reply.body)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("投稿詳細")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.startListeningReplies(
                postId: item.id,
                organizationId: organizationId
            )

            if item.hasUnreadReply {
                store.markReplyAsRead(
                    postId: item.id,
                    organizationId: organizationId
                )
            }
        }
        .onDisappear {
            store.stopListeningReplies()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
