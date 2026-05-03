import SwiftUI
import FirebaseFirestore

struct MemberPostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var memberStore: MemberStore
    @EnvironmentObject private var organizationStore: OrganizationStore

    @StateObject private var store = MemberPostStore()

    @State private var title: String = ""
    @State private var messageBody: String = ""

    @State private var isSubmitting = false
    @State private var showCompleteAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private let db = Firestore.firestore()

    var body: some View {
        Form {
            Section("件名") {
                TextField("件名を入力", text: $title)
            }

            Section("内容") {
                TextEditor(text: $messageBody)
                    .frame(minHeight: 180)
            }

            Section {
                Button {
                    submit()
                } label: {
                    if isSubmitting {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("送信中...")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("送信する")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(
                    isSubmitting ||
                    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }

            Section {
                NavigationLink {
                    MemberPostHistoryView()
                        .environmentObject(memberStore)
                        .environmentObject(organizationStore)
                } label: {
                    Label("投稿履歴を見る", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .navigationTitle("管理者へ投稿")
        .navigationBarTitleDisplayMode(.inline)
        .alert("送信しました", isPresented: $showCompleteAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("管理者へ投稿を送信しました。")
        }
        .alert("エラー", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func submit() {
        let organizationId = organizationStore.organization.id
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let memberUid = memberStore.authUid?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let memberName = memberStore.profile?.name
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = messageBody.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !organizationId.isEmpty else {
            errorMessage = "organizationId が取得できません。"
            showErrorAlert = true
            return
        }

        guard !memberUid.isEmpty else {
            errorMessage = "会員UIDが取得できません。"
            showErrorAlert = true
            return
        }

        guard !trimmedTitle.isEmpty else {
            errorMessage = "件名を入力してください。"
            showErrorAlert = true
            return
        }

        guard !trimmedBody.isEmpty else {
            errorMessage = "内容を入力してください。"
            showErrorAlert = true
            return
        }

        isSubmitting = true

        print("organizationId:", organizationId)
        print("memberUid:", memberUid)
        print("memberName:", memberName)

        let data: [String: Any] = [
            "memberUid": memberUid,
            "memberName": memberName,
            "title": trimmedTitle,
            "body": trimmedBody,
            "status": "new",
            "memberHasReadReply": true,
            "replyCount": 0,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection("organizations")
            .document(organizationId)
            .collection("memberPosts")
            .addDocument(data: data) { error in
                isSubmitting = false

                if let error {
                    errorMessage = "送信に失敗しました: \(error.localizedDescription)"
                    showErrorAlert = true
                    return
                }

                title = ""
                messageBody = ""
                showCompleteAlert = true
            }
    }
}
