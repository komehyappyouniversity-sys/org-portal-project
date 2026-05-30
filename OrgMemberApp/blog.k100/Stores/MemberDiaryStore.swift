import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit
import Combine

@MainActor
final class MemberDiaryStore: ObservableObject {

    @Published var diaries: [MemberDiary] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?

    func startListening(organizationId: String, uid: String) {
        stopListening()

        guard !organizationId.isEmpty, !uid.isEmpty else {
            diaries = []
            return
        }

        isLoading = true
        errorMessage = ""

        listener = db
            .collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)
            .collection("diaries")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    self.diaries = snapshot?.documents.map {
                        MemberDiary(id: $0.documentID, data: $0.data())
                    } ?? []
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func saveDiary(
        organizationId: String,
        uid: String,
        existingDiary: MemberDiary?,
        title: String,
        body: String,
        mood: String,
        newImages: [UIImage]
    ) async {
        guard !organizationId.isEmpty, !uid.isEmpty else {
            errorMessage = "団体情報またはログイン情報が確認できません。"
            return
        }

        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "本文を入力してください。"
            return
        }

        isLoading = true
        errorMessage = ""

        do {
            let diaryRef: DocumentReference

            if let existingDiary {
                diaryRef = db
                    .collection("organizations")
                    .document(organizationId)
                    .collection("members")
                    .document(uid)
                    .collection("diaries")
                    .document(existingDiary.id)
            } else {
                diaryRef = db
                    .collection("organizations")
                    .document(organizationId)
                    .collection("members")
                    .document(uid)
                    .collection("diaries")
                    .document()
            }

            var imageURLs = existingDiary?.imageURLs ?? []

            if !newImages.isEmpty {
                let uploadedURLs = try await uploadImages(
                    organizationId: organizationId,
                    uid: uid,
                    diaryId: diaryRef.documentID,
                    images: newImages
                )
                imageURLs.append(contentsOf: uploadedURLs)
            }

            if imageURLs.count > 3 {
                imageURLs = Array(imageURLs.prefix(3))
            }

            let now = Timestamp(date: Date())

            var data: [String: Any] = [
                "title": title,
                "body": body,
                "mood": mood,
                "imageURLs": imageURLs,
                "updatedAt": now
            ]

            if existingDiary == nil {
                data["createdAt"] = now
            }

            try await diaryRef.setData(data, merge: true)

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func deleteDiary(
        organizationId: String,
        uid: String,
        diary: MemberDiary
    ) async {
        guard !organizationId.isEmpty, !uid.isEmpty else { return }

        isLoading = true
        errorMessage = ""

        do {
            try await db
                .collection("organizations")
                .document(organizationId)
                .collection("members")
                .document(uid)
                .collection("diaries")
                .document(diary.id)
                .delete()

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func uploadImages(
        organizationId: String,
        uid: String,
        diaryId: String,
        images: [UIImage]
    ) async throws -> [String] {
        var urls: [String] = []

        for image in images.prefix(3) {
            guard let data = image.jpegData(compressionQuality: 0.65) else {
                continue
            }

            let fileName = UUID().uuidString + ".jpg"

            let ref = storage.reference()
                .child("organizations")
                .child(organizationId)
                .child("members")
                .child(uid)
                .child("diaryImages")
                .child(diaryId)
                .child(fileName)

            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            _ = try await ref.putDataAsync(data, metadata: metadata)
            let url = try await ref.downloadURL()
            urls.append(url.absoluteString)
        }

        return urls
    }
}
