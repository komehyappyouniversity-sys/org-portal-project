//
//  AdminVimeoVideoStore.swift
//  ictnagaoka-admin
//

import Foundation
import Combine
import FirebaseFunctions
import FirebaseFirestore

@MainActor
final class AdminVimeoVideoStore: ObservableObject {
    @Published var videos: [AdminVimeoVideo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var savingVideoIds: Set<String> = []
    @Published var registeredVideoIds: Set<String> = []
    @Published var registeredVideosById: [String: AdminRegisteredVideo] = [:]

    private lazy var functions = Functions.functions(region: "us-central1")
    private let db = Firestore.firestore()

    func loadRegisteredVideos(organizationId: String) {
        let trimmedOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOrganizationId.isEmpty else {
            errorMessage = "organizationId が空です。"
            registeredVideoIds = []
            registeredVideosById = [:]
            return
        }

        db.collection("organizations")
            .document(trimmedOrganizationId)
            .collection("videos")
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                Task { @MainActor in
                    if let error {
                        self.errorMessage = "登録済み動画の取得に失敗しました: \(error.localizedDescription)"
                        self.registeredVideoIds = []
                        self.registeredVideosById = [:]
                        return
                    }

                    let documents = snapshot?.documents ?? []

                    var ids = Set<String>()
                    var map: [String: AdminRegisteredVideo] = [:]

                    for doc in documents {
                        let data = doc.data()
                        let vimeoVideoId = data["vimeoVideoId"] as? String ?? ""

                        guard !vimeoVideoId.isEmpty else { continue }

                        let category = data["category"] as? String ?? "未分類"
                        let isPremium = data["isPremium"] as? Bool ?? false
                        let isPublished = data["isPublished"] as? Bool ?? false

                        ids.insert(vimeoVideoId)
                        map[vimeoVideoId] = AdminRegisteredVideo(
                            vimeoVideoId: vimeoVideoId,
                            category: category,
                            isPremium: isPremium,
                            isPublished: isPublished
                        )
                    }

                    self.registeredVideoIds = ids
                    self.registeredVideosById = map
                }
            }
    }

    func loadVideos(
        organizationId: String,
        page: Int = 1,
        perPage: Int = 20
    ) {
        let trimmedOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOrganizationId.isEmpty else {
            errorMessage = "organizationId が空です。"
            videos = []
            return
        }

        loadRegisteredVideos(organizationId: trimmedOrganizationId)

        isLoading = true
        errorMessage = nil

        let data: [String: Any] = [
            "page": page,
            "perPage": perPage
        ]

        print("========== AdminVimeoVideoStore loadVideos ==========")
        print("organizationId:", trimmedOrganizationId)
        print("call function: listVimeoVideos")

        functions.httpsCallable("listVimeoVideos").call(data) { [weak self] result, error in
            guard let self else { return }

            Task { @MainActor in
                self.isLoading = false

                if let error {
                    self.errorMessage = "Vimeo一覧の取得に失敗しました: \(error.localizedDescription)"
                    self.videos = []
                    print("❌ Vimeo list error:", error.localizedDescription)
                    return
                }

                guard
                    let dict = result?.data as? [String: Any],
                    let rawVideos = dict["videos"] as? [[String: Any]]
                else {
                    self.errorMessage = "レスポンス形式が不正です。"
                    self.videos = []
                    print("❌ Vimeo response format invalid")
                    return
                }

                self.videos = rawVideos.map { item in
                    let uri = item["uri"] as? String ?? ""
                    let vimeoVideoId = item["vimeoVideoId"] as? String ?? ""
                    let name = item["name"] as? String ?? ""
                    let description = item["description"] as? String ?? ""
                    let duration = item["duration"] as? Int ?? 0
                    let link = item["link"] as? String ?? ""
                    let privacyView = item["privacyView"] as? String ?? ""
                    let privacyEmbed = item["privacyEmbed"] as? String ?? ""
                    let thumbnailUrl = item["thumbnailUrl"] as? String ?? ""
                    let createdTime = item["createdTime"] as? String ?? ""
                    let modifiedTime = item["modifiedTime"] as? String ?? ""

                    return AdminVimeoVideo(
                        id: vimeoVideoId.isEmpty ? UUID().uuidString : vimeoVideoId,
                        uri: uri,
                        vimeoVideoId: vimeoVideoId,
                        name: name,
                        description: description,
                        duration: duration,
                        link: link,
                        embedHtml: "",
                        privacyView: privacyView,
                        privacyEmbed: privacyEmbed,
                        thumbnailUrl: thumbnailUrl,
                        createdTime: createdTime,
                        modifiedTime: modifiedTime
                    )
                }

                print("✅ Vimeo videos loaded:", self.videos.count)
            }
        }
    }

    func registerToFirestore(
        organizationId: String,
        video: AdminVimeoVideo,
        category: String,
        isPremium: Bool,
        isPublished: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let trimmedOrganizationId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOrganizationId.isEmpty else {
            let error = NSError(
                domain: "AdminVimeoVideoStore",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "organizationId が空です。"]
            )
            errorMessage = error.localizedDescription
            completion(.failure(error))
            return
        }

        errorMessage = nil
        savingVideoIds.insert(video.id)

        let sortOrder = Int(Date().timeIntervalSince1970)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCategory = trimmedCategory.isEmpty ? "未分類" : trimmedCategory

        let payload: [String: Any] = [
            "organizationId": trimmedOrganizationId,
            "title": video.name,
            "description": video.description,
            "vimeoVideoId": video.vimeoVideoId,
            "vimeoUri": video.uri,
            "thumbnailUrl": video.thumbnailUrl,
            "duration": video.duration,
            "link": video.link,
            "privacyView": video.privacyView,
            "privacyEmbed": video.privacyEmbed,
            "category": finalCategory,
            "isPremium": isPremium,
            "isPublished": isPublished,
            "published": isPublished,
            "sortOrder": sortOrder,
            "source": "vimeo",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        let docId = video.vimeoVideoId.isEmpty ? UUID().uuidString : video.vimeoVideoId

        print("========== AdminVimeoVideoStore registerToFirestore ==========")
        print("save path: organizations/\(trimmedOrganizationId)/videos/\(docId)")
        print("title:", video.name)
        print("vimeoVideoId:", video.vimeoVideoId)

        db.collection("organizations")
            .document(trimmedOrganizationId)
            .collection("videos")
            .document(docId)
            .setData(payload, merge: true) { [weak self] error in
                guard let self else { return }

                Task { @MainActor in
                    self.savingVideoIds.remove(video.id)

                    if let error {
                        self.errorMessage = "Firestore登録に失敗しました: \(error.localizedDescription)"
                        print("❌ video save error:", error.localizedDescription)
                        completion(.failure(error))
                    } else {
                        self.registeredVideoIds.insert(video.vimeoVideoId)
                        self.registeredVideosById[video.vimeoVideoId] = AdminRegisteredVideo(
                            vimeoVideoId: video.vimeoVideoId,
                            category: finalCategory,
                            isPremium: isPremium,
                            isPublished: isPublished
                        )

                        print("✅ video saved to organization videos")
                        completion(.success(()))
                    }
                }
            }
    }

    func isRegistered(_ video: AdminVimeoVideo) -> Bool {
        registeredVideoIds.contains(video.vimeoVideoId)
    }

    func registeredVideo(for video: AdminVimeoVideo) -> AdminRegisteredVideo? {
        registeredVideosById[video.vimeoVideoId]
    }
}
