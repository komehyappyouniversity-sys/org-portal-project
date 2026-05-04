import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MemberMessageDetailView: View {
    @EnvironmentObject private var store: MemberMessageStore

    let item: MemberMessageItem
    let organizationId: String

    @State private var attachments: [MessageAttachment] = []
    @State private var zoomURL = ""
    @State private var videoURL = ""

    private let db = Firestore.firestore()

    private var currentItem: MemberMessageItem {
        store.items.first(where: { $0.id == item.id }) ?? item
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                Text(currentItem.title)
                    .font(.title2.bold())

                Text(currentItem.body)
                    .font(.body)

                if let url = URL(string: zoomURL), !zoomURL.isEmpty {
                    Link("Zoomを開く", destination: url)
                        .font(.headline)
                }

                if let url = URL(string: videoURL), !videoURL.isEmpty {
                    Link("動画URLを開く", destination: url)
                        .font(.headline)
                }

                if !attachments.isEmpty {
                    Divider()

                    Text("添付ファイル")
                        .font(.headline)

                    ForEach(attachments) { attachment in
                        attachmentView(attachment)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("お知らせ詳細")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadExtraData()
            await markAsRead()
        }
    }

    @ViewBuilder
    private func attachmentView(_ attachment: MessageAttachment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if attachment.type == "image",
               let url = URL(string: attachment.url) {

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(12)

                    case .failure:
                        Text("画像を表示できませんでした")
                            .foregroundColor(.red)

                    @unknown default:
                        EmptyView()
                    }
                }

            } else if let url = URL(string: attachment.url) {
                Link(
                    attachment.name.isEmpty ? "添付ファイルを開く" : attachment.name,
                    destination: url
                )
                .font(.body.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
    }

    private func loadExtraData() async {
        let id = currentItem.id
        guard !id.isEmpty else { return }

        do {
            let snapshot = try await db
                .collection("organizations")
                .document(organizationId)
                .collection("messages")
                .document(id)
                .getDocument()

            let data = snapshot.data() ?? [:]

            zoomURL = data["zoomURL"] as? String ?? ""
            videoURL = data["videoURL"] as? String ?? ""

            let rawAttachments = data["attachments"] as? [[String: Any]] ?? []

            attachments = rawAttachments.map { dict in
                MessageAttachment(
                    type: dict["type"] as? String ?? "",
                    name: dict["name"] as? String ?? "",
                    url: dict["url"] as? String ?? ""
                )
            }

        } catch {
            print("❌ 添付データ取得エラー:", error.localizedDescription)
        }
    }

    private func markAsRead() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let id = currentItem.id
        guard !id.isEmpty else { return }

        do {
            try await db
                .collection("organizations")
                .document(organizationId)
                .collection("messages")
                .document(id)
                .updateData([
                    "isReadBy": FieldValue.arrayUnion([uid])
                ])

            print("✅ 既読更新:", id)

        } catch {
            print("❌ 既読更新エラー:", error.localizedDescription)
        }
    }
}

private struct MessageAttachment: Identifiable {
    let id = UUID()
    let type: String
    let name: String
    let url: String
}
