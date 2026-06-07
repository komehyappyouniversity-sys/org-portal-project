import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AdminVideoManagementStore: ObservableObject {

    @Published var videos: [AdminManagedVideo] = []
    @Published var isLoading = false
    @Published var message = ""
    @Published var isError = false

    private let db = Firestore.firestore()

    func fetchFromVimeo(organizationId: String) {
        Task {
            await fetchFromVimeoAsync(organizationId: organizationId)
        }
    }

    private func fetchFromVimeoAsync(organizationId: String) async {
        let safeOrganizationId = organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !safeOrganizationId.isEmpty else {
            showError("organizationId がありません")
            return
        }

        guard let user = Auth.auth().currentUser else {
            showError("ログインされていません")
            return
        }

        isLoading = true
        message = ""
        isError = false

        do {
            let savedVideos = try await loadSavedVideos(
                organizationId: safeOrganizationId
            )

            let token = try await user.getIDToken()

            guard let url = URL(
                string: "https://asia-northeast1-ictnagaoka-member.cloudfunctions.net/fetchVimeoVideosHttp"
            ) else {
                showError("URLが不正です")
                return
            }

            let body: [String: Any] = [
                "organizationId": safeOrganizationId
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                showError("レスポンス取得失敗")
                return
            }

            print("🎥 fetchVimeoVideosHttp status:", http.statusCode)
            print("🎥 fetchVimeoVideosHttp response:", String(data: data, encoding: .utf8) ?? "")

            guard http.statusCode == 200 else {
                showError("Vimeo動画取得失敗（\(http.statusCode)）")
                return
            }

            let decoded = try JSONDecoder().decode(VimeoFetchResponse.self, from: data)

            let managedVideos = decoded.videos.map { item in
                let saved = savedVideos[item.id]

                return AdminManagedVideo(
                    id: item.id,
                    title: item.title,
                    description: item.description,
                    vimeoVideoId: item.id,
                    thumbnailUrl: item.thumbnailUrl.isEmpty
                        ? (saved?.thumbnailUrl ?? "")
                        : item.thumbnailUrl,
                    videoUrl: item.link,
                    isPublished: saved?.isPublished ?? false,
                    isMembersOnly: saved?.isMembersOnly ?? true,
                    isPremium: saved?.isPremium ?? false,
                    price: saved?.price ?? 0,
                    priceText: saved?.priceText ?? "",
                    billingType: saved?.billingType ?? "monthly",
                    productId: saved?.productId ?? "",
                    sortOrder: saved?.sortOrder ?? 0
                )
            }

            self.videos = managedVideos.sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.title < $1.title
                }
                return $0.sortOrder < $1.sortOrder
            }

            self.message = "Vimeoから \(managedVideos.count) 件読み込みました"
            self.isError = false
            self.isLoading = false

        } catch {
            showError("Vimeo動画取得失敗: \(error.localizedDescription)")
        }
    }

    private func loadSavedVideos(
        organizationId: String
    ) async throws -> [String: AdminManagedVideo] {

        let snapshot = try await db.collection("organizations")
            .document(organizationId)
            .collection("videos")
            .getDocuments()

        var result: [String: AdminManagedVideo] = [:]

        for document in snapshot.documents {
            let data = document.data()

            let vimeoVideoId = data["vimeoVideoId"] as? String ?? document.documentID

            let video = AdminManagedVideo(
                id: document.documentID,
                title: data["title"] as? String ?? "",
                description: data["description"] as? String ?? "",
                vimeoVideoId: vimeoVideoId,
                thumbnailUrl: data["thumbnailUrl"] as? String ?? "",
                videoUrl: data["videoUrl"] as? String ?? "",
                isPublished: data["isPublished"] as? Bool ?? false,
                isMembersOnly: data["isMembersOnly"] as? Bool ?? true,
                isPremium: data["isPremium"] as? Bool ?? false,
                price: data["price"] as? Int ?? 0,
                priceText: data["priceText"] as? String ?? "",
                billingType: data["billingType"] as? String ?? "monthly",
                productId: data["productId"] as? String ?? "",
                sortOrder: data["sortOrder"] as? Int ?? 0,
                createdAt: data["createdAt"] as? Timestamp,
                updatedAt: data["updatedAt"] as? Timestamp
            )

            result[vimeoVideoId] = video
        }

        return result
    }

    func saveVideo(_ video: AdminManagedVideo, organizationId: String) {
        Task {
            await saveVideoAsync(video, organizationId: organizationId)
        }
    }

    private func saveVideoAsync(
        _ video: AdminManagedVideo,
        organizationId: String
    ) async {
        let safeOrganizationId = organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !safeOrganizationId.isEmpty else {
            showError("organizationId がありません")
            return
        }

        let docId = video.vimeoVideoId.isEmpty
            ? UUID().uuidString
            : video.vimeoVideoId

        let data: [String: Any] = [
            "title": video.title,
            "description": video.description,
            "vimeoVideoId": video.vimeoVideoId,
            "thumbnailUrl": video.thumbnailUrl,
            "videoUrl": video.videoUrl,
            "isPublished": video.isPublished,
            "isMembersOnly": video.isMembersOnly,
            "isPremium": video.isPremium,
            "price": video.price,
            "priceText": video.priceText,
            "billingType": video.billingType,
            "productId": video.productId,
            "sortOrder": video.sortOrder,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        do {
            try await db.collection("organizations")
                .document(safeOrganizationId)
                .collection("videos")
                .document(docId)
                .setData(data, merge: true)

            message = "保存しました"
            isError = false

        } catch {
            showError("保存失敗: \(error.localizedDescription)")
        }
    }

    func saveAll(organizationId: String) {
        guard !videos.isEmpty else {
            showError("保存する動画がありません")
            return
        }

        for video in videos {
            saveVideo(video, organizationId: organizationId)
        }
    }

    func updateVideo(_ video: AdminManagedVideo) {
        guard let index = videos.firstIndex(where: { $0.vimeoVideoId == video.vimeoVideoId }) else {
            return
        }

        videos[index] = video
    }

    private func showError(_ text: String) {
        isLoading = false
        message = text
        isError = true
    }
}

private struct VimeoFetchResponse: Decodable {
    let ok: Bool
    let videos: [VimeoVideoItem]
}

private struct VimeoVideoItem: Decodable {
    let id: String
    let title: String
    let description: String
    let link: String
    let duration: Int
    let thumbnailUrl: String
    let createdTime: String
}
