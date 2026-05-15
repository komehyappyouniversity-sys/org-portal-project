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
                AdminManagedVideo(
                    id: item.id,
                    title: item.title,
                    description: item.description,
                    vimeoVideoId: item.id,
                    thumbnailUrl: item.thumbnailUrl,
                    videoUrl: item.link,
                    isPublished: false,
                    isMembersOnly: true,
                    isPremium: false,
                    price: 0,
                    priceText: "",
                    billingType: "monthly",
                    sortOrder: 0
                )
            }

            self.videos = managedVideos
            self.message = "Vimeoから \(managedVideos.count) 件読み込みました"
            self.isError = false
            self.isLoading = false

        } catch {
            showError("Vimeo動画取得失敗: \(error.localizedDescription)")
        }
    }

    func saveVideo(_ video: AdminManagedVideo, organizationId: String) {
        Task {
            await saveVideoAsync(video, organizationId: organizationId)
        }
    }

    private func saveVideoAsync(_ video: AdminManagedVideo, organizationId: String) async {
        let safeOrganizationId = organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !safeOrganizationId.isEmpty else {
            showError("organizationId がありません")
            return
        }

        let docId = video.vimeoVideoId.isEmpty ? UUID().uuidString : video.vimeoVideoId

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
