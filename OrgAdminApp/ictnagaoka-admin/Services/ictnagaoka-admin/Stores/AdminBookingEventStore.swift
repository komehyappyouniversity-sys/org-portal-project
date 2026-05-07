//
//  AdminBookingEventStore.swift
//  ictnagaoka-admin
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class AdminBookingEventStore: ObservableObject {

    @Published var events: [AdminBookingEvent] = []
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
            .order(by: "eventDate", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in

                guard let self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        print("❌ bookingEvents listen error:", error.localizedDescription)
                        return
                    }

                    self.events = snapshot?.documents.map { document in
                        let data = document.data()

                        return AdminBookingEvent(
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

                    print("✅ bookingEvents loaded:", self.events.count)
                }
            }
    }

    func saveEvent(
        organizationId: String,
        event: AdminBookingEvent
    ) async {

        guard !organizationId.isEmpty else {
            errorMessage = "organizationId が空です"
            return
        }

        do {
            let collection = db
                .collection("organizations")
                .document(organizationId)
                .collection("bookingEvents")

            let now = Timestamp(date: Date())

            var data: [String: Any] = [
                "title": event.title,
                "description": event.description,
                "eventDate": Timestamp(date: event.eventDate),
                "feeAmount": event.feeAmount,
                "appStoreProductId": event.appStoreProductId,
                "paymentRequired": event.paymentRequired,
                "zoomURL": event.zoomURL,
                "isPublished": event.isPublished,
                "updatedAt": now
            ]

            if let createdAt = event.createdAt {
                data["createdAt"] = Timestamp(date: createdAt)
            } else {
                data["createdAt"] = now
            }

            if let eventId = event.id {
                try await collection.document(eventId).setData(data, merge: true)
                print("✅ bookingEvent updated:", eventId)
            } else {
                let document = collection.document()
                try await document.setData(data)
                print("✅ bookingEvent created:", document.documentID)
            }

        } catch {
            errorMessage = error.localizedDescription
            print("❌ saveEvent error:", error.localizedDescription)
        }
    }

    func deleteEvent(
        organizationId: String,
        eventId: String
    ) async {

        guard !organizationId.isEmpty else {
            errorMessage = "organizationId が空です"
            return
        }

        do {
            try await db
                .collection("organizations")
                .document(organizationId)
                .collection("bookingEvents")
                .document(eventId)
                .delete()

            print("🗑 bookingEvent deleted:", eventId)

        } catch {
            errorMessage = error.localizedDescription
            print("❌ deleteEvent error:", error.localizedDescription)
        }
    }
}
