import Foundation
import Combine
import FirebaseFirestore

struct SharedManualAttachment: Identifiable, Equatable {
    let id: String
    var type: String
    var name: String
    var url: String

    init(
        id: String = UUID().uuidString,
        type: String,
        name: String,
        url: String
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.url = url
    }

    init(data: [String: Any]) {
        self.id = data["id"] as? String ?? UUID().uuidString
        self.type = data["type"] as? String ?? ""
        self.name = data["name"] as? String ?? ""
        self.url = data["url"] as? String ?? ""
    }

    var dictionary: [String: Any] {
        [
            "id": id,
            "type": type,
            "name": name,
            "url": url
        ]
    }
}

struct SharedManualItem: Identifiable {
    let id: String
    var title: String
    var body: String
    var sortOrder: Int
    var isPublished: Bool
    var attachments: [SharedManualAttachment]
    var createdAt: Date?
    var updatedAt: Date?
}

@MainActor
final class SharedManualStore: ObservableObject {
    @Published var manuals: [SharedManualItem] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening() {
        if listener != nil { return }

        isLoading = true
        errorMessage = ""

        listener = db.collection("sharedManuals")
            .order(by: "sortOrder", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    let documents = snapshot?.documents ?? []

                    self.manuals = documents.map { document in
                        let data = document.data()

                        let rawAttachments =
                            data["attachments"] as? [[String: Any]] ?? []

                        let attachments = rawAttachments.map {
                            SharedManualAttachment(data: $0)
                        }

                        return SharedManualItem(
                            id: document.documentID,
                            title: data["title"] as? String ?? "",
                            body: data["body"] as? String ?? "",
                            sortOrder: data["sortOrder"] as? Int ?? 0,
                            isPublished: data["isPublished"] as? Bool ?? true,
                            attachments: attachments,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
                        )
                    }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func createManual(
        manualId: String,
        title: String,
        body: String,
        sortOrder: Int,
        isPublished: Bool,
        attachments: [SharedManualAttachment]
    ) async {
        errorMessage = ""

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            errorMessage = "タイトルを入力してください"
            return
        }

        guard !trimmedBody.isEmpty else {
            errorMessage = "本文を入力してください"
            return
        }

        do {
            try await db.collection("sharedManuals")
                .document(manualId)
                .setData([
                "title": trimmedTitle,
                "body": trimmedBody,
                "sortOrder": sortOrder,
                "isPublished": isPublished,
                "attachments": attachments.map { $0.dictionary },
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateManual(
        manualId: String,
        title: String,
        body: String,
        sortOrder: Int,
        isPublished: Bool,
        attachments: [SharedManualAttachment]
    ) async {
        errorMessage = ""

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            errorMessage = "タイトルを入力してください"
            return
        }

        guard !trimmedBody.isEmpty else {
            errorMessage = "本文を入力してください"
            return
        }

        do {
            try await db.collection("sharedManuals")
                .document(manualId)
                .updateData([
                    "title": trimmedTitle,
                    "body": trimmedBody,
                    "sortOrder": sortOrder,
                    "isPublished": isPublished,
                    "attachments": attachments.map { $0.dictionary },
                    "updatedAt": FieldValue.serverTimestamp()
                ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteManual(_ manual: SharedManualItem) async {
        errorMessage = ""

        do {
            try await db.collection("sharedManuals")
                .document(manual.id)
                .delete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
