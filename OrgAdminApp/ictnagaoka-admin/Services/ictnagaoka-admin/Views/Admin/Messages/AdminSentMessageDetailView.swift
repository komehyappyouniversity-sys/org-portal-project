import SwiftUI
import FirebaseFirestore

struct AdminSentMessageDetailView: View {
    let message: AdminSentMessage

    @EnvironmentObject var organizationStore: AdminOrganizationStore

    private let db = Firestore.firestore()

    @State private var targetMembers: [AdminMessageMember] = []
    @State private var isLoading = false
    @State private var isResending = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    private var organizationId: String {
        let id = organizationStore.currentOrganizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !id.isEmpty {
            return id
        }

        return OrganizationConfig.organizationId
    }

    private var readMembers: [AdminMessageMember] {
        targetMembers.filter { message.isReadBy.contains($0.uid) }
    }

    private var unreadMembers: [AdminMessageMember] {
        targetMembers.filter { !message.isReadBy.contains($0.uid) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                Text(message.title)
                    .font(.title2.bold())

                Text(message.body)
                    .font(.body)

                Divider()

                HStack {
                    statBox(title: "対象", count: targetMembers.count)
                    statBox(title: "既読", count: readMembers.count)
                    statBox(title: "未読", count: unreadMembers.count)
                }

                if isLoading {
                    ProgressView("会員情報を読み込み中...")
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                if !unreadMembers.isEmpty {
                    Divider()

                    Text("未読会員")
                        .font(.headline)

                    ForEach(unreadMembers) { member in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name.isEmpty ? "名前未登録" : member.name)
                                .font(.body.bold())

                            Text(member.uid)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Button {
                        Task {
                            await resendToUnreadMembers()
                        }
                    } label: {
                        HStack {
                            if isResending {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(isResending ? "再送中..." : "未読会員だけに再送")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isResending)

                } else if !targetMembers.isEmpty {
                    Text("未読会員はいません。")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("既読状況")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTargetMembers()
        }
        .alert("再送しました", isPresented: $showSuccess) {
            Button("OK") {}
        } message: {
            Text("未読会員だけに再送しました。")
        }
    }

    private func statBox(title: String, count: Int) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(count)")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func loadTargetMembers() async {
        isLoading = true
        errorMessage = ""

        do {
            let snapshot = try await db
                .collection("organizations")
                .document(organizationId)
                .collection("members")
                .getDocuments()

            let approvedMembers: [AdminMessageMember] = snapshot.documents.compactMap { doc in
                let data = doc.data()

                let status = data["status"] as? String ?? ""

                guard status == "approved" || status == "active" else {
                    return nil
                }

                let categories = data["categories"] as? [String] ?? []
                let legacyCategory = data["category"] as? String ?? ""

                return AdminMessageMember(
                    uid: doc.documentID,
                    name: data["name"] as? String ?? "",
                    categories: categories + (
                        legacyCategory.isEmpty ? [] : [legacyCategory]
                    )
                )
            }

            targetMembers = resolveTargetMembers(
                from: approvedMembers
            )

        } catch {
            errorMessage = "会員情報の読み込みに失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func resolveTargetMembers(
        from approvedMembers: [AdminMessageMember]
    ) -> [AdminMessageMember] {

        if message.isBroadcast {
            return approvedMembers
        }

        if !message.categoryTargets.isEmpty {
            let categoryTargetSet = Set(message.categoryTargets)

            return approvedMembers.filter { member in
                member.categories.contains { category in
                    categoryTargetSet.contains(category)
                }
            }
        }

        let targetSet = Set(
            message.targetMemberUids + message.toUids
        )

        return approvedMembers.filter { member in
            targetSet.contains(member.uid)
        }
    }

    private func resendToUnreadMembers() async {
        let unreadUids = unreadMembers.map { $0.uid }

        print("===== 未読者だけ再送 開始 =====")
        print("organizationId:", organizationId)
        print("unreadUids:", unreadUids)
        print("unreadCount:", unreadUids.count)

        guard !unreadUids.isEmpty else {
            errorMessage = "未読会員がいないため再送できません。"
            print("❌ 未読会員なし")
            return
        }

        isResending = true
        errorMessage = ""

        do {
            let newMessageRef = db
                .collection("organizations")
                .document(organizationId)
                .collection("messages")
                .document()

            let data: [String: Any] = [
                "title": "【再送】\(message.title)",
                "body": message.body,
                "organizationId": organizationId,
                "messageType": "memberMessage",
                "isBroadcast": false,
                "categoryTargets": [],
                "targetMemberUids": unreadUids,
                "toUids": unreadUids,
                "isReadBy": [],
                "attachments": message.attachments,
                "zoomURL": message.zoomURL,
                "videoURL": message.videoURL,
                "resendOfMessageId": message.id,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]

            print("保存先:", newMessageRef.path)
            print("保存データ:", data)

            try await newMessageRef.setData(data)

            print("✅ 未読者だけ再送 保存成功")

            showSuccess = true

        } catch {
            print(
                "❌ 未読者だけ再送 保存失敗:",
                error.localizedDescription
            )

            errorMessage = "再送に失敗しました: \(error.localizedDescription)"
        }

        isResending = false
    }
}

struct AdminMessageMember: Identifiable {
    let uid: String
    let name: String
    let categories: [String]

    var id: String { uid }
}
