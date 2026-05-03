import SwiftUI

struct MemberPostDetailView: View {
    @EnvironmentObject private var store: MemberPostStore
    let item: MemberPostItem
    let organizationId: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.title)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.body)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                if item.hasUnreadReply {
                    Text("未読返信あり")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .cornerRadius(8)
                }

                if let replyText = item.replyBody, !replyText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("管理者からの返信")
                            .font(.headline)

                        Text(replyText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("投稿詳細")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if item.hasUnreadReply {
                store.markReplyAsRead(postId: item.id, organizationId: organizationId)
            }
        }
    }
}
