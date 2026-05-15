import SwiftUI

struct AdminMemberPostDetailView: View {
    @EnvironmentObject private var organizationStore: AdminOrganizationStore
    @ObservedObject var store: AdminMemberPostStore

    let item: AdminMemberPostItem

    @State private var currentItem: AdminMemberPostItem
    @State private var replyText: String = ""

    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var localErrorMessage = ""

    private var organizationId: String {
        organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(item: AdminMemberPostItem, store: AdminMemberPostStore) {
        self.item = item
        self.store = store
        _currentItem = State(initialValue: item)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                postSection
                statusSection
                repliesSection
                replyInputSection
            }
            .padding(16)
        }
        .navigationTitle("会員投稿詳細")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startRepliesListening()
            syncCurrentItem()
        }
        .onDisappear {
            store.stopListeningReplies()
        }
        .onReceive(store.$posts) { _ in
            syncCurrentItem()
        }
        .onReceive(store.$replies) { _ in
            syncCurrentItem()
        }
        .alert("返信を保存しました", isPresented: $showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("返信履歴に追加しました。")
        }
        .alert("エラー", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(localErrorMessage)
        }
    }

    private var postSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentItem.title)
                .font(.title3.bold())

            if !currentItem.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(currentItem.body)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            HStack(spacing: 8) {
                statusBadge(currentItem.status)

                if currentItem.replyCount > 0 {
                    Text("返信 \(currentItem.replyCount)件")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }

                if currentItem.memberHasReadReply == false {
                    Text("会員未読")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }

            infoRow(
                title: "会員名",
                value: currentItem.memberName.isEmpty
                    ? "未設定"
                    : currentItem.memberName
            )

            infoRow(
                title: "UID",
                value: currentItem.memberUid.isEmpty
                    ? "未設定"
                    : currentItem.memberUid
            )

            if let createdAt = currentItem.createdAt {
                infoRow(title: "投稿日", value: dateTimeText(createdAt))
            }

            if let updatedAt = currentItem.updatedAt {
                infoRow(title: "更新日", value: dateTimeText(updatedAt))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("対応状況")
                .font(.headline)

            HStack(spacing: 10) {
                statusButton(title: "新着", value: "new")
                statusButton(title: "対応中", value: "in_progress")
                statusButton(title: "解決", value: "resolved")
                statusButton(title: "終了", value: "closed")
            }
        }
    }

    private func statusButton(title: String, value: String) -> some View {
        Button {
            Task {
                do {
                    try await store.updateStatus(
                        organizationId: organizationId,
                        postId: currentItem.id,
                        status: value
                    )
                } catch {
                    localErrorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        } label: {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(currentItem.status == value ? .white : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    currentItem.status == value
                        ? Color.blue
                        : Color.blue.opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("返信履歴")
                .font(.headline)

            if store.isRepliesLoading && store.replies.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()

                    Text("返信履歴を読み込んでいます...")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            if !store.errorMessage.isEmpty {
                Text(store.errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.red)
            }

            if currentItem.replies.isEmpty {
                ContentUnavailableView(
                    "返信はまだありません",
                    systemImage: "bubble.left",
                    description: Text(
                        "下の入力欄から返信を追加すると、ここに履歴表示されます。"
                    )
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)

            } else {
                ForEach(currentItem.replies) { reply in
                    replyCard(reply)
                }
            }
        }
    }

    private func replyCard(_ reply: AdminMemberPostReplyItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(
                    reply.createdByName ??
                    (reply.isFromAdmin ? "管理者" : "返信")
                )
                .font(.subheadline.bold())

                Spacer()

                if let createdAt = reply.createdAt {
                    Text(dateTimeText(createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(reply.body)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var replyInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("返信を追加")
                .font(.headline)

            TextEditor(text: $replyText)
                .frame(minHeight: 140)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                sendReply()
            } label: {
                if store.isSendingReply {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("保存中...")
                    }
                    .frame(maxWidth: .infinity)

                } else {
                    Text("返信を保存")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                store.isSendingReply ||
                replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }

    private func sendReply() {
        Task {
            do {
                try await store.sendReply(
                    organizationId: organizationId,
                    postId: currentItem.id,
                    replyBody: replyText,
                    adminName: "管理者"
                )

                replyText = ""
                showSuccessAlert = true

            } catch {
                localErrorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func startRepliesListening() {
        guard !organizationId.isEmpty else {
            return
        }

        store.startListeningReplies(
            organizationId: organizationId,
            postId: item.id
        )
    }

    private func syncCurrentItem() {
        if let latest = store.posts.first(where: { $0.id == item.id }) {
            var merged = latest
            merged.replies = store.replies
            currentItem = merged
        } else {
            currentItem = item
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer(minLength: 0)
        }
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
        case "new":
            return "新着"

        case "in_progress":
            return "対応中"

        case "resolved":
            return "解決"

        case "closed":
            return "終了"

        default:
            return status
        }
    }

    private func statusTextColor(_ status: String) -> Color {
        switch status {
        case "new":
            return .orange

        case "in_progress":
            return .blue

        case "resolved":
            return .green

        case "closed":
            return .secondary

        default:
            return .secondary
        }
    }

    private func statusBackgroundColor(_ status: String) -> Color {
        switch status {
        case "new":
            return Color.orange.opacity(0.15)

        case "in_progress":
            return Color.blue.opacity(0.15)

        case "resolved":
            return Color.green.opacity(0.15)

        case "closed":
            return Color.gray.opacity(0.15)

        default:
            return Color.gray.opacity(0.12)
        }
    }

    private func dateTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"

        return formatter.string(from: date)
    }
}
