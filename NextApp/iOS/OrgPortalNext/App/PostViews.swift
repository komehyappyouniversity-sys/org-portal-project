import DataLayer
import DesignSystem
import Model
import Session
import SwiftUI

@MainActor
final class PostFeatureModel: ObservableObject {
    @Published private(set) var publicPosts: [PublicPost] = []
    @Published private(set) var memberPosts: [MemberPost] = []
    @Published private(set) var replies: [AdminReply] = []
    @Published private(set) var managementMemberPosts: [MemberPost] = []
    @Published var selectedPublicPost: PublicPost?
    @Published var selectedMemberPost: MemberPost?
    @Published var selectedManagementMemberPost: MemberPost?
    @Published var editorPost: MemberPost?
    @Published var editorTitle = ""
    @Published var editorBody = ""
    @Published var managementReplyDraft = ""
    @Published var isEditing = false
    @Published private(set) var isLoading = false
    @Published var message: String?

    let session: AppSession
    private let repository: any PostRepository
    private let memberships: () -> [CommunityMembership]

    init(
        repository: any PostRepository,
        session: AppSession,
        memberships: @escaping () -> [CommunityMembership]
    ) {
        self.repository = repository
        self.session = session
        self.memberships = memberships
    }

    var approvedMembership: CommunityMembership? {
        memberships().first {
            $0.communityId == session.selectedCommunityId && $0.status == .approved
        }
    }

    func refreshPublic() {
        load {
            self.publicPosts = try await self.repository.publicPosts()
        }
    }

    func refreshMember() {
        guard let membership = approvedMembership,
              let userID = session.authenticatedUserId,
              let token = session.authenticationToken else {
            memberPosts = []
            return
        }
        load {
            self.memberPosts = try await self.repository.memberPosts(
                communityId: membership.communityId,
                userId: userID,
                idToken: token
            )
        }
    }

    func refreshManagementMemberPosts() {
        guard let membership = approvedMembership,
              let token = session.authenticationToken else {
            managementMemberPosts = []
            return
        }
        load {
            self.managementMemberPosts = try await self.repository.allMemberPosts(
                communityId: membership.communityId,
                idToken: token,
            )
        }
    }

    func open(_ post: MemberPost) {
        selectedMemberPost = post
        replies = []
        guard let token = session.authenticationToken else { return }
        Task {
            do {
                replies = try await repository.replies(
                    communityId: post.communityId,
                    postId: post.id,
                    idToken: token
                )
                if post.hasUnreadReply {
                    try await repository.markReplyRead(
                        communityId: post.communityId,
                        postId: post.id,
                        idToken: token
                    )
                }
            } catch {
                message = "返信を読み込めませんでした。"
            }
        }
    }

    func closeDetail() {
        selectedMemberPost = nil
        selectedPublicPost = nil
        replies = []
        refreshMember()
    }

    func startCreate() {
        editorPost = nil
        editorTitle = ""
        editorBody = ""
        isEditing = true
        message = nil
    }

    func startEdit(_ post: MemberPost) {
        selectedMemberPost = nil
        editorPost = post
        editorTitle = post.title
        editorBody = post.body
        isEditing = true
    }

    func cancelEditor() {
        editorPost = nil
        editorTitle = ""
        editorBody = ""
        isEditing = false
    }

    func save() {
        guard let membership = approvedMembership,
              let userID = session.authenticatedUserId,
              let token = session.authenticationToken else {
            message = "承認済みコミュニティを選択してください。"
            return
        }
        let title = editorTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = editorBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !body.isEmpty else {
            message = "タイトルと本文を入力してください。"
            return
        }
        let editing = editorPost
        load {
            if let editing {
                try await self.repository.updateMemberPost(
                    communityId: editing.communityId,
                    postId: editing.id,
                    title: title,
                    body: body,
                    idToken: token
                )
            } else {
                try await self.repository.createMemberPost(
                    communityId: membership.communityId,
                    userId: userID,
                    authorName: membership.applicantName ?? "会員",
                    title: title,
                    body: body,
                    idToken: token
                )
            }
            self.cancelEditor()
            self.message = "投稿を保存しました。"
            self.refreshMember()
        }
    }

    func delete(_ post: MemberPost) {
        guard let token = session.authenticationToken else { return }
        load {
            try await self.repository.deleteMemberPost(
                communityId: post.communityId,
                postId: post.id,
                idToken: token
            )
            self.selectedMemberPost = nil
            self.message = "投稿を削除しました。"
            self.refreshMember()
        }
    }

    func startManagementReply(for post: MemberPost) {
        selectedManagementMemberPost = post
        managementReplyDraft = post.legacyAdminReply ?? ""
    }

    func updateManagementReplyDraft(_ value: String) {
        managementReplyDraft = value
    }

    func closeManagementReply() {
        selectedManagementMemberPost = nil
        managementReplyDraft = ""
    }

    func saveManagementReply() {
        guard let post = selectedManagementMemberPost,
              let userID = session.authenticatedUserId,
              let token = session.authenticationToken else {
            message = "承認済みコミュニティを選択してください。"
            return
        }
        let body = managementReplyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            message = "返信内容を入力してください。"
            return
        }
        load {
            try await self.repository.saveAdminReply(
                communityId: post.communityId,
                postId: post.id,
                adminUserId: userID,
                adminName: self.approvedMembership?.applicantName ?? "管理者",
                body: body,
                idToken: token,
            )
            self.selectedManagementMemberPost = nil
            self.managementReplyDraft = ""
            self.message = "返信を保存しました。"
            self.refreshManagementMemberPosts()
        }
    }

    private func load(_ operation: @escaping () async throws -> Void) {
        isLoading = true
        message = nil
        Task {
            do {
                try await operation()
                isLoading = false
            } catch {
                isLoading = false
                message = "投稿を処理できませんでした。時間をおいて再度お試しください。"
            }
        }
    }
}

struct PostRootView: View {
    @ObservedObject var model: PostFeatureModel
    @State private var selection = 0

    private var identity: String {
        [
            model.session.selectedCommunityId ?? "public",
            model.session.authenticatedUserId ?? "guest"
        ].joined(separator: ":")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("投稿", selection: $selection) {
                    Text("公開投稿").tag(0)
                    Text("会員投稿").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                Group {
                    if model.isLoading {
                        LoadingState()
                    } else if selection == 0 {
                        publicList
                    } else {
                        memberList
                    }
                }
            }
            .navigationTitle("投稿")
            .toolbar {
                if selection == 1 && model.approvedMembership != nil {
                    Button("新規投稿", action: model.startCreate)
                }
                Button("更新") {
                    selection == 0 ? model.refreshPublic() : model.refreshMember()
                }
            }
            .task(id: identity) {
                model.refreshPublic()
                model.refreshMember()
            }
            .sheet(item: $model.selectedPublicPost) {
                PublicPostDetailView(post: $0)
            }
            .sheet(item: $model.selectedMemberPost) {
                MemberPostDetailView(model: model, post: $0)
            }
            .sheet(isPresented: $model.isEditing) {
                MemberPostEditorView(model: model)
            }
        }
    }

    private var publicList: some View {
        Group {
            if model.publicPosts.isEmpty {
                EmptyState("公開投稿はまだありません", systemImage: "text.bubble")
            } else {
                List(model.publicPosts) { post in
                    Button {
                        model.selectedPublicPost = post
                    } label: {
                        PostRow(
                            author: post.authorName,
                            title: post.title.isEmpty ? (post.categoryId ?? "公開投稿") : post.title,
                            postBody: post.body,
                            isUnread: false
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var memberList: some View {
        Group {
            if model.approvedMembership == nil {
                PermissionRequiredState(
                    "承認済みコミュニティを選択すると会員投稿を利用できます。"
                )
            } else if model.memberPosts.isEmpty {
                EmptyState("会員投稿はまだありません", systemImage: "square.and.pencil")
            } else {
                List(model.memberPosts) { post in
                    Button { model.open(post) } label: {
                        PostRow(
                            author: post.authorName,
                            title: post.title,
                            postBody: post.body,
                            isUnread: post.hasUnreadReply
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let message = model.message {
                Text(message)
                    .font(.footnote)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial)
            }
        }
    }
}

private struct PostRow: View {
    let author: String
    let title: String?
    let postBody: String
    let isUnread: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isUnread ? "bubble.left.and.exclamationmark.bubble.right" : "text.bubble")
                .foregroundStyle(isUnread ? .orange : .green)
            VStack(alignment: .leading, spacing: 5) {
                if let title, !title.isEmpty {
                    Text(title).font(.headline).foregroundStyle(.primary)
                }
                Text(postBody).lineLimit(3).foregroundStyle(.primary)
                Text(author).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

private struct PublicPostDetailView: View {
    let post: PublicPost
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(post.authorName).font(.headline)
                    Text(post.body).frame(maxWidth: .infinity, alignment: .leading)
                    attachmentLinks(post.attachments)
                }
                .padding(24)
            }
            .navigationTitle("公開投稿")
            .toolbar { Button("閉じる") { dismiss() } }
        }
    }
}

private struct MemberPostDetailView: View {
    @ObservedObject var model: PostFeatureModel
    let post: MemberPost
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(post.title).font(.title2.bold())
                    Text(post.body).frame(maxWidth: .infinity, alignment: .leading)
                    attachmentLinks(post.attachments)
                    if let reply = post.legacyAdminReply, !reply.isEmpty {
                        replyCard(name: "管理者", body: reply)
                    }
                    ForEach(model.replies) {
                        replyCard(name: $0.adminName ?? "管理者", body: $0.body)
                    }
                    if post.canEdit(userId: model.session.authenticatedUserId ?? "") {
                        Button("編集") {
                            dismiss()
                            model.startEdit(post)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("削除", role: .destructive) {
                            model.delete(post)
                            dismiss()
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("会員投稿")
            .toolbar {
                Button("閉じる") {
                    model.closeDetail()
                    dismiss()
                }
            }
        }
    }

    private func replyCard(name: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.caption.bold()).foregroundStyle(.secondary)
            Text(body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct MemberPostEditorView: View {
    @ObservedObject var model: PostFeatureModel

    var body: some View {
        NavigationStack {
            Form {
                TextField("タイトル", text: $model.editorTitle)
                TextEditor(text: $model.editorBody).frame(minHeight: 180)
                if let message = model.message {
                    Text(message).foregroundStyle(.red)
                }
            }
            .navigationTitle(model.editorPost == nil ? "投稿を作成" : "投稿を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: model.cancelEditor)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: model.save).disabled(model.isLoading)
                }
            }
        }
    }
}

@ViewBuilder
@MainActor
private func attachmentLinks(_ attachments: [PostAttachment]) -> some View {
    ForEach(Array(attachments.enumerated()), id: \.offset) { _, attachment in
        Link(attachment.name, destination: attachment.url)
            .buttonStyle(.bordered)
    }
}
