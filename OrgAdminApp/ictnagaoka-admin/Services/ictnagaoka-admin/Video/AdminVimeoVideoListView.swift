import SwiftUI
import FirebaseFunctions
import FirebaseFirestore

struct AdminVimeoVideoItem: Identifiable {
    let id: String
    let title: String
    let description: String
    let thumbnailUrl: String
    let vimeoUrl: String
    let embedHtml: String
}

struct AdminVimeoVideoListView: View {
    @EnvironmentObject var organizationStore: AdminOrganizationStore

    @State private var videos: [AdminVimeoVideoItem] = []
    @State private var registeredIds: Set<String> = []

    @State private var isLoading = false
    @State private var message = ""

    private let functions = Functions.functions(region: "asia-northeast1")
    private let db = Firestore.firestore()

    var body: some View {
        List {
            if isLoading {
                ProgressView("Vimeo動画を取得中...")
            }

            if !message.isEmpty {
                Text(message)
                    .foregroundColor(message.contains("失敗") ? .red : .green)
            }

            ForEach(videos) { video in
                VStack(alignment: .leading, spacing: 10) {

                    Text(video.title)
                        .font(.headline)

                    if !video.description.isEmpty {
                        Text(video.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    if registeredIds.contains(video.id) {

                        HStack {
                            Label("登録済み", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)

                            Spacer()

                            Button(role: .destructive) {
                                unregisterVideo(video)
                            } label: {
                                Text("登録解除")
                            }
                        }

                    } else {

                        Button("Firestoreに登録") {
                            registerVideo(video)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Vimeo動画一覧")
        .toolbar {
            Button("取得") {
                fetchVideos()
            }
        }
        .onAppear {
            fetchVideos()
        }
    }

    private func fetchVideos() {
        isLoading = true
        message = ""

        let data: [String: Any] = [
            "organizationId": organizationStore.organization.id
        ]

        functions.httpsCallable("fetchVimeoVideos").call(data) { result, error in

            isLoading = false

            if let error {
                message = "動画取得失敗: \(error.localizedDescription)"
                return
            }

            guard
                let dict = result?.data as? [String: Any],
                let items = dict["videos"] as? [[String: Any]]
            else {
                message = "動画データを読み取れませんでした"
                return
            }

            videos = items.compactMap { item in

                guard let id = item["id"] as? String else {
                    return nil
                }

                return AdminVimeoVideoItem(
                    id: id,
                    title: item["title"] as? String ?? "",
                    description: item["description"] as? String ?? "",
                    thumbnailUrl: item["thumbnailUrl"] as? String ?? "",
                    vimeoUrl: item["vimeoUrl"] as? String ?? "",
                    embedHtml: item["embedHtml"] as? String ?? ""
                )
            }

            loadRegisteredVideos()

            message = "\(videos.count)件の動画を取得しました"
        }
    }

    private func loadRegisteredVideos() {

        let orgId = organizationStore.organization.id

        guard !orgId.isEmpty else {
            return
        }

        db.collection("organizations")
            .document(orgId)
            .collection("videos")
            .getDocuments { snapshot, error in

                guard let documents = snapshot?.documents else {
                    return
                }

                registeredIds = Set(documents.map { $0.documentID })
            }
    }

    private func registerVideo(_ video: AdminVimeoVideoItem) {

        let orgId = organizationStore.organization.id

        guard !orgId.isEmpty else {
            message = "organizationId がありません"
            return
        }

        let data: [String: Any] = [
            "title": video.title,
            "description": video.description,
            "vimeoVideoId": video.id,
            "thumbnailUrl": video.thumbnailUrl,
            "vimeoUrl": video.vimeoUrl,
            "embedHtml": video.embedHtml,
            "isPublished": true,
            "isPremium": false,
            "category": "",
            "sortOrder": 0,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection("organizations")
            .document(orgId)
            .collection("videos")
            .document(video.id)
            .setData(data, merge: true) { error in

                if let error {
                    message = "Firestore登録失敗: \(error.localizedDescription)"
                } else {

                    registeredIds.insert(video.id)

                    message = "Firestoreに登録しました: \(video.title)"
                }
            }
    }

    private func unregisterVideo(_ video: AdminVimeoVideoItem) {

        let orgId = organizationStore.organization.id

        guard !orgId.isEmpty else {
            message = "organizationId がありません"
            return
        }

        db.collection("organizations")
            .document(orgId)
            .collection("videos")
            .document(video.id)
            .delete { error in

                if let error {
                    message = "登録解除失敗: \(error.localizedDescription)"
                } else {

                    registeredIds.remove(video.id)

                    message = "登録解除しました: \(video.title)"
                }
            }
    }
}
