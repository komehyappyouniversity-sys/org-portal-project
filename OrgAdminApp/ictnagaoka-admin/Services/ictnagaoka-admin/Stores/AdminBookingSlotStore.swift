//
//  AdminBookingSlotStore.swift
//  ictnagaoka-admin
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class AdminBookingSlotStore: ObservableObject {

    @Published var slots: [AdminBookingSlot] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(
        organizationId: String,
        eventId: String
    ) {
        guard !organizationId.isEmpty else {
            errorMessage = "organizationId が空です"
            return
        }

        guard !eventId.isEmpty else {
            errorMessage = "eventId が空です"
            return
        }

        isLoading = true
        errorMessage = ""

        listener?.remove()

        listener = db
            .collection("organizations")
            .document(organizationId)
            .collection("bookingEvents")
            .document(eventId)
            .collection("slots")
            .order(by: "startAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        print("❌ booking slots listen error:", error.localizedDescription)
                        return
                    }

                    self.slots = snapshot?.documents.map { document in
                        let data = document.data()

                        return AdminBookingSlot(
                            id: document.documentID,
                            startAt: (data["startAt"] as? Timestamp)?.dateValue() ?? Date(),
                            endAt: (data["endAt"] as? Timestamp)?.dateValue() ?? Date().addingTimeInterval(60 * 60),
                            capacity: data["capacity"] as? Int ?? 1,
                            reservedCount: data["reservedCount"] as? Int ?? 0,
                            paidCount: data["paidCount"] as? Int ?? 0,
                            isOpen: data["isOpen"] as? Bool ?? true,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
                        )
                    } ?? []

                    print("✅ booking slots loaded:", self.slots.count)
                }
            }
    }

    func saveSlot(
        organizationId: String,
        eventId: String,
        slot: AdminBookingSlot
    ) async {
        guard !organizationId.isEmpty else {
            errorMessage = "organizationId が空です"
            return
        }

        guard !eventId.isEmpty else {
            errorMessage = "eventId が空です"
            return
        }

        do {
            let collection = db
                .collection("organizations")
                .document(organizationId)
                .collection("bookingEvents")
                .document(eventId)
                .collection("slots")

            let now = Timestamp(date: Date())

            var data: [String: Any] = [
                "startAt": Timestamp(date: slot.startAt),
                "endAt": Timestamp(date: slot.endAt),
                "capacity": slot.capacity,
                "reservedCount": slot.reservedCount,
                "paidCount": slot.paidCount,
                "isOpen": slot.isOpen,
                "updatedAt": now
            ]

            if let createdAt = slot.createdAt {
                data["createdAt"] = Timestamp(date: createdAt)
            } else {
                data["createdAt"] = now
            }

            if let slotId = slot.id {
                try await collection.document(slotId).setData(data, merge: true)
                print("✅ booking slot updated:", slotId)
            } else {
                let document = collection.document()
                try await document.setData(data)
                print("✅ booking slot created:", document.documentID)
            }

        } catch {
            errorMessage = error.localizedDescription
            print("❌ saveSlot error:", error.localizedDescription)
        }
    }

    func deleteSlot(
        organizationId: String,
        eventId: String,
        slotId: String
    ) async {
        guard !organizationId.isEmpty else {
            errorMessage = "organizationId が空です"
            return
        }

        guard !eventId.isEmpty else {
            errorMessage = "eventId が空です"
            return
        }

        do {
            try await db
                .collection("organizations")
                .document(organizationId)
                .collection("bookingEvents")
                .document(eventId)
                .collection("slots")
                .document(slotId)
                .delete()

            print("🗑 booking slot deleted:", slotId)

        } catch {
            errorMessage = error.localizedDescription
            print("❌ deleteSlot error:", error.localizedDescription)
        }
    }
}
