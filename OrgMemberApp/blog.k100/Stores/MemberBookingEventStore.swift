//
//  MemberBookingEventStore.swift
//  blog.k100
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class MemberBookingEventStore: ObservableObject {

    @Published var events: [MemberBookingEvent] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(organizationId: String) {
        guard !organizationId.isEmpty else {
            errorMessage = "organizationId が空です"
            return
        }

        isLoading = true
        errorMessage = ""

        listener?.remove()

        listener = db
            .collection("organizations")
            .document(organizationId)
            .collection("bookingEvents")
            .whereField("isPublished", isEqualTo: true)
            .order(by: "eventDate", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        print("❌ member bookingEvents listen error:", error.localizedDescription)
                        return
                    }

                    self.events = snapshot?.documents.map { document in
                        let data = document.data()

                        return MemberBookingEvent(
                            id: document.documentID,
                            title: data["title"] as? String ?? "",
                            description: data["description"] as? String ?? "",
                            eventDate: (data["eventDate"] as? Timestamp)?.dateValue() ?? Date(),
                            feeAmount: data["feeAmount"] as? Int ?? 0,
                            appStoreProductId: data["appStoreProductId"] as? String ?? "",
                            paymentRequired: data["paymentRequired"] as? Bool ?? true,
                            zoomURL: data["zoomURL"] as? String ?? "",
                            isPublished: data["isPublished"] as? Bool ?? false,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
                        )
                    } ?? []

                    print("✅ member bookingEvents loaded:", self.events.count)
                }
            }
    }
}
