import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class AdminBookingReservationStore: ObservableObject {
    @Published var reservations: [AdminBookingReservation] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(
        organizationId: String,
        eventId: String,
        slotId: String
    ) {
        listener?.remove()

        guard !organizationId.isEmpty else {
            errorMessage = "organizationId がありません"
            reservations = []
            return
        }

        guard !eventId.isEmpty else {
            errorMessage = "eventId がありません"
            reservations = []
            return
        }

        guard !slotId.isEmpty else {
            errorMessage = "slotId がありません"
            reservations = []
            return
        }

        isLoading = true
        errorMessage = ""

        print("✅ 予約者一覧 listen path:")
        print("organizations/\(organizationId)/bookingEvents/\(eventId)/slots/\(slotId)/bookings")

        listener = db
            .collection("organizations")
            .document(organizationId)
            .collection("bookingEvents")
            .document(eventId)
            .collection("slots")
            .document(slotId)
            .collection("bookings")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    self.isLoading = false

                    if let error {
                        self.errorMessage = "予約者一覧を読み込めませんでした: \(error.localizedDescription)"
                        self.reservations = []
                        print("❌ 予約者一覧 load error:", error.localizedDescription)
                        return
                    }

                    let documents = snapshot?.documents ?? []

                    var loadedReservations = documents.map { document in
                        AdminBookingReservation(
                            documentId: document.documentID,
                            data: document.data()
                        )
                    }

                    for index in loadedReservations.indices {
                        let uid = loadedReservations[index].memberUid

                        guard !uid.isEmpty else {
                            continue
                        }

                        do {
                            let memberSnapshot = try await self.db
                                .collection("organizations")
                                .document(organizationId)
                                .collection("members")
                                .document(uid)
                                .getDocument()

                            let memberData = memberSnapshot.data() ?? [:]

                            let name =
                                memberData["name"] as? String ??
                                memberData["memberName"] as? String ??
                                memberData["displayName"] as? String ??
                                ""

                            let email =
                                memberData["email"] as? String ??
                                memberData["memberEmail"] as? String ??
                                ""

                            if !name.isEmpty {
                                loadedReservations[index].memberName = name
                            }

                            if !email.isEmpty {
                                loadedReservations[index].memberEmail = email
                            }

                        } catch {
                            print("❌ member read error:", uid, error.localizedDescription)
                        }
                    }

                    self.reservations = loadedReservations

                    print("✅ 予約者数:", self.reservations.count)
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
