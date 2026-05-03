import Foundation
import FirebaseFirestore

@MainActor
final class VideoStore: ObservableObject {
    @Published var videos: [VideoItem] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening(organizationId: String) {
        listener?.remove()

        isLoading = true

        listener = db.collection("organizations")
            .document(organizationId)
            .collection("videos")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                self.isLoading = false

                if let docs = snapshot?.documents {
                    self.videos = docs.compactMap { VideoItem(doc: $0) }
                }
            }
    }

    deinit {
        listener?.remove()
    }
}
