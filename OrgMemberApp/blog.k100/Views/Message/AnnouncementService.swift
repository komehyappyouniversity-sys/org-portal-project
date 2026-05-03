import Foundation
import FirebaseFirestore

struct AnnouncementItem: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let createdAt: Date?
}

protocol AnnouncementServiceProtocol {
    func listenAnnouncements(
        organizationId: String,
        onChange: @escaping (Result<[AnnouncementItem], Error>) -> Void
    ) -> ListenerRegistration
}

final class AnnouncementService: AnnouncementServiceProtocol {
    private let db = Firestore.firestore()

    func listenAnnouncements(
        organizationId: String,
        onChange: @escaping (Result<[AnnouncementItem], Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("organizations")
            .document(organizationId)
            .collection("announcements")
            .whereField("isPublished", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let items = (snapshot?.documents ?? []).map { doc in
                    let data = doc.data()

                    return AnnouncementItem(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "お知らせ",
                        body: data["body"] as? String ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
                    )
                }

                onChange(.success(items))
            }
    }
}
