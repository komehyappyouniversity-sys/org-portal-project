//
//  DiaryStore.swift
//  blog.k100
//
//  Created by 根津浩 on 2026/04/14.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage

struct DiaryEntry: Identifiable, Equatable {
    let id: String
    let uid: String
    let date: Date
    let title: String
    let body: String
    let imageUrls: [String]
    let createdAt: Date?
    let updatedAt: Date?

    init(
        id: String,
        uid: String,
        date: Date,
        title: String,
        body: String,
        imageUrls: [String] = [],
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.uid = uid
        self.date = date
        self.title = title
        self.body = body
        self.imageUrls = imageUrls
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        let uid = data["uid"] as? String ?? ""
        guard !uid.isEmpty else { return nil }

        let dateTimestamp = data["date"] as? Timestamp ?? data["createdAt"] as? Timestamp
        let title = data["title"] as? String ?? ""
        let body = data["body"] as? String ?? ""
        let imageUrls = data["imageUrls"] as? [String] ?? []
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()

        self.id = document.documentID
        self.uid = uid
        self.date = dateTimestamp?.dateValue() ?? Date()
        self.title = title
        self.body = body
        self.imageUrls = imageUrls
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@MainActor
final class DiaryStore: ObservableObject {
    @Published var entries: [DiaryEntry] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    // MARK: - Listen

    func startListening(
        organizationId: String,
        uid: String
    ) {
        stopListening()

        isLoading = true
        errorMessage = nil

        let db = Firestore.firestore()

        listener = db
            .collection("organizations")
            .document(organizationId)
            .collection("diaryEntries")
            .whereField("uid", isEqualTo: uid)
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                Task { @MainActor in
                    if let error {
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                        print("DiaryStore startListening error:", error.localizedDescription)
                        return
                    }

                    let docs = snapshot?.documents ?? []
                    self.entries = docs.compactMap { DiaryEntry(document: $0) }
                    self.isLoading = false
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Create

    func saveEntry(
        organizationId: String,
        uid: String,
        date: Date,
        title: String,
        body: String,
        imageDatas: [Data],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let db = Firestore.firestore()
                let ref = db
                    .collection("organizations")
                    .document(organizationId)
                    .collection("diaryEntries")
                    .document()

                let entryId = ref.documentID

                let uploadedUrls = try await uploadImages(
                    organizationId: organizationId,
                    uid: uid,
                    entryId: entryId,
                    imageDatas: imageDatas
                )

                let data: [String: Any] = [
                    "uid": uid,
                    "date": Timestamp(date: date),
                    "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
                    "body": body.trimmingCharacters(in: .whitespacesAndNewlines),
                    "imageUrls": uploadedUrls,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ]

                try await ref.setData(data)

                self.isSaving = false
                self.errorMessage = nil
                completion(.success(()))
            } catch {
                self.isSaving = false
                self.errorMessage = error.localizedDescription
                print("DiaryStore saveEntry error:", error.localizedDescription)
                completion(.failure(error))
            }
        }
    }

    // MARK: - Update

    func updateEntry(
        organizationId: String,
        uid: String,
        entryId: String,
        date: Date,
        title: String,
        body: String,
        existingImageUrls: [String],
        newImageDatas: [Data],
        originalImageUrls: [String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            do {
                // 1. 画面上で残っている既存画像URLのうち、
                //    Storage上に実在するものだけ残す
                let validExistingImageUrls = await filterExistingImageUrlsToOnlyExisting(existingImageUrls)

                // 2. 新しい画像をアップロード
                let uploadedUrls = try await uploadImages(
                    organizationId: organizationId,
                    uid: uid,
                    entryId: entryId,
                    imageDatas: newImageDatas
                )

                // 3. 実在する既存URL + 新規アップロードURL だけ保存
                let mergedImageUrls = validExistingImageUrls + uploadedUrls

                let db = Firestore.firestore()
                let ref = db
                    .collection("organizations")
                    .document(organizationId)
                    .collection("diaryEntries")
                    .document(entryId)

                let data: [String: Any] = [
                    "date": Timestamp(date: date),
                    "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
                    "body": body.trimmingCharacters(in: .whitespacesAndNewlines),
                    "imageUrls": mergedImageUrls,
                    "updatedAt": FieldValue.serverTimestamp()
                ]

                try await ref.updateData(data)

                // 4. 今回は削除エラー切り分けのため Storage 削除はしない
                //    Firestore の imageUrls だけ正しい状態へ直す

                self.isSaving = false
                self.errorMessage = nil
                completion(.success(()))
            } catch {
                self.isSaving = false
                self.errorMessage = error.localizedDescription
                print("DiaryStore updateEntry error:", error.localizedDescription)
                completion(.failure(error))
            }
        }
    }

    // MARK: - Delete Entry

    func deleteEntry(
        organizationId: String,
        entry: DiaryEntry,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let db = Firestore.firestore()
                let ref = db
                    .collection("organizations")
                    .document(organizationId)
                    .collection("diaryEntries")
                    .document(entry.id)

                try await ref.delete()

                // 今回はまず本体削除優先。Storage画像削除はしない
                self.isSaving = false
                self.errorMessage = nil
                completion(.success(()))
            } catch {
                self.isSaving = false
                self.errorMessage = error.localizedDescription
                print("DiaryStore deleteEntry error:", error.localizedDescription)
                completion(.failure(error))
            }
        }
    }

    // MARK: - Upload Images

    private func uploadImages(
        organizationId: String,
        uid: String,
        entryId: String,
        imageDatas: [Data]
    ) async throws -> [String] {
        guard !imageDatas.isEmpty else { return [] }

        let storage = Storage.storage()
        var urls: [String] = []

        for (index, data) in imageDatas.enumerated() {
            let fileName = "\(UUID().uuidString)_\(index).jpg"
            let path = "organizations/\(organizationId)/diaryEntries/\(uid)/\(entryId)/\(fileName)"
            let ref = storage.reference().child(path)

            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            _ = try await ref.putDataAsync(data, metadata: metadata)
            let downloadURL = try await ref.downloadURL()
            urls.append(downloadURL.absoluteString)
        }

        return urls
    }

    // MARK: - Existing URL Validation

    private func filterExistingImageUrlsToOnlyExisting(_ urls: [String]) async -> [String] {
        guard !urls.isEmpty else { return [] }

        var validUrls: [String] = []

        for urlString in urls {
            let exists = await storageObjectExists(forURLString: urlString)
            if exists {
                validUrls.append(urlString)
            } else {
                print("DiaryStore removed broken image URL before save:", urlString)
            }
        }

        return validUrls
    }

    private func storageObjectExists(forURLString urlString: String) async -> Bool {
        do {
            let ref = Storage.storage().reference(forURL: urlString)
            _ = try await getMetadataAsync(ref: ref)
            return true
        } catch {
            let nsError = error as NSError
            if nsError.domain == StorageErrorDomain &&
                nsError.code == StorageErrorCode.objectNotFound.rawValue {
                return false
            }
            // objectNotFound 以外は、ひとまず残す方が安全
            print("DiaryStore metadata check skipped/error:", error.localizedDescription)
            return true
        }
    }

    private func getMetadataAsync(ref: StorageReference) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { continuation in
            ref.getMetadata { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "DiaryStore",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "metadata is nil"]
                    ))
                }
            }
        }
    }
}
