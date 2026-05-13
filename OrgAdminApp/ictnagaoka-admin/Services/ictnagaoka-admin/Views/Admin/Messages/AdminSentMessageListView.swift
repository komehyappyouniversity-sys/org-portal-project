import SwiftUI
import FirebaseFirestore

struct AdminSentMessageListView: View {
    @EnvironmentObject private var organizationStore: OrganizationStore

    private let db = Firestore.firestore()

    @State private var messages: [AdminSentMessage] = []
    @State private var isLoading = false
    @State private var errorMessage = ""

    private var organizationId: String {
        organizationStore.organization.id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            if organizationId.isEmpty {
                Text("organizationId がありません")
                    .foregroundColor(.red)

            } else if isLoading {
                ProgressView("読み込み中...")

            } else if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)

            } else if messages.isEmpty {
                Text("送信済みメッセージはありません")
                    .foregroundColor(.secondary)

            } else {
                ForEach(messages) { message in
                    NavigationLink {
                        AdminSentMessageDetailView(message: message)
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(message.title)
                                    .font(.headline)

                                Text(message.body)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)

                                Text(formatDate(message.createdAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                countText(label: "対象", count: message.targetCount, color: .blue)
                                countText(label: "既読", count: message.readCount, color: .green)
                                countText(label: "未読", count: message.unreadCount, color: .red)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("送信済み一覧")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: organizationId) {
            await loadMessages()
        }
    }

    private func countText(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("\(count)")
                .font(.caption.bold())
                .foregroundColor(color)
        }
    }

    private func loadMessages() async {
        guard !organizationId.isEmpty else {
            errorMessage = "organizationId がありません"
            messages = []
            return
        }

        print("📨 AdminSentMessageListView organizationId:", organizationId)

        isLoading = true
        errorMessage = ""

        do {
            let membersSnapshot = try await db
                .collection("organizations")
                .document(organizationId)
                .collection("members")
                .getDocuments()

            let members = membersSnapshot.documents.compactMap { doc -> AdminMessageMember? in
                let data = doc.data()
                let status = data["status"] as? String ?? ""

                guard status == "approved" else {
                    return nil
                }

                let categories = data["categories"] as? [String] ?? []
                let legacyCategory = data["category"] as? String ?? ""

                return AdminMessageMember(
                    uid: doc.documentID,
                    name: data["name"] as? String ?? "",
                    categories: categories + (legacyCategory.isEmpty ? [] : [legacyCategory])
                )
            }

            let snapshot = try await db
                .collection("organizations")
                .document(organizationId)
                .collection("messages")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            messages = snapshot.documents.compactMap { doc in
                let data = doc.data()

                let messageType = data["messageType"] as? String ?? ""
                guard messageType == "memberMessage" else {
                    return nil
                }

                let isBroadcast = data["isBroadcast"] as? Bool ?? false
                let categoryTargets = data["categoryTargets"] as? [String] ?? []
                let targetMemberUids = data["targetMemberUids"] as? [String] ?? []
                let toUids = data["toUids"] as? [String] ?? []
                let isReadBy = data["isReadBy"] as? [String] ?? []

                let targetMembers = resolveTargetMembers(
                    members: members,
                    isBroadcast: isBroadcast,
                    categoryTargets: categoryTargets,
                    targetMemberUids: targetMemberUids,
                    toUids: toUids
                )

                let targetUids = Set(targetMembers.map { $0.uid })
                let readUids = Set(isReadBy)
                let readCount = targetUids.intersection(readUids).count
                let unreadCount = max(targetMembers.count - readCount, 0)

                return AdminSentMessage(
                    id: doc.documentID,
                    title: data["title"] as? String ?? "",
                    body: data["body"] as? String ?? "",
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    isBroadcast: isBroadcast,
                    categoryTargets: categoryTargets,
                    targetMemberUids: targetMemberUids,
                    toUids: toUids,
                    isReadBy: isReadBy,
                    attachments: data["attachments"] as? [[String: Any]] ?? [],
                    zoomURL: data["zoomURL"] as? String ?? "",
                    videoURL: data["videoURL"] as? String ?? "",
                    targetCount: targetMembers.count,
                    readCount: readCount,
                    unreadCount: unreadCount
                )
            }

        } catch {
            errorMessage = "読み込みに失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func resolveTargetMembers(
        members: [AdminMessageMember],
        isBroadcast: Bool,
        categoryTargets: [String],
        targetMemberUids: [String],
        toUids: [String]
    ) -> [AdminMessageMember] {
        if isBroadcast {
            return members
        }

        if !categoryTargets.isEmpty {
            return members.filter { member in
                member.categories.contains { category in
                    categoryTargets.contains(category)
                }
            }
        }

        let targetSet = Set(targetMemberUids + toUids)
        return members.filter { targetSet.contains($0.uid) }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

struct AdminSentMessage: Identifiable {
    let id: String
    let title: String
    let body: String
    let createdAt: Date
    let isBroadcast: Bool
    let categoryTargets: [String]
    let targetMemberUids: [String]
    let toUids: [String]
    let isReadBy: [String]
    let attachments: [[String: Any]]
    let zoomURL: String
    let videoURL: String

    let targetCount: Int
    let readCount: Int
    let unreadCount: Int
}
