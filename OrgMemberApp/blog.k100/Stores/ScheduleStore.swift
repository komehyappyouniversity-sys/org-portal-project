import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class ScheduleStore: ObservableObject {
    @Published var events: [ScheduleEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(organizationId: String) {
        listener?.remove()
        isLoading = true
        errorMessage = nil

        let db = Firestore.firestore()

        listener = db.collection("organizations")
            .document(organizationId)
            .collection("events")
            .order(by: "startAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.errorMessage = error.localizedDescription
                    self.events = []
                    self.isLoading = false
                    print("ScheduleStore listen error:", error.localizedDescription)
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.events = []
                    self.isLoading = false
                    return
                }

                self.events = documents.compactMap { ScheduleEvent(document: $0) }
                self.isLoading = false
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
