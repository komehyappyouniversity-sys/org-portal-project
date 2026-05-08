//
//  MemberBookingSlotStore.swift
//  blog.k100
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class MemberBookingSlotStore: ObservableObject {

    @Published var slots: [MemberBookingSlot] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var successMessage = ""
    @Published var isBooking = false

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
        successMessage = ""

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
                        print("❌ slots listen error:", error.localizedDescription)
                        return
                    }

                    self.slots = snapshot?.documents.map { document in
                        let data = document.data()

                        return MemberBookingSlot(
                            id: document.documentID,
                            startAt: (data["startAt"] as? Timestamp)?.dateValue() ?? Date(),
                            endAt: (data["endAt"] as? Timestamp)?.dateValue() ?? Date(),
                            capacity: data["capacity"] as? Int ?? 0,
                            reservedCount: data["reservedCount"] as? Int ?? 0,
                            paidCount: data["paidCount"] as? Int ?? 0,
                            isOpen: data["isOpen"] as? Bool ?? true
                        )
                    } ?? []

                    print("✅ member slots loaded:", self.slots.count)
                }
            }
    }

    func book(
        organizationId: String,
        eventId: String,
        slot: MemberBookingSlot
    ) {
        guard !organizationId.isEmpty else {
            errorMessage = "organizationId が空です"
            return
        }

        guard !eventId.isEmpty else {
            errorMessage = "eventId が空です"
            return
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "ログイン情報を取得できませんでした。"
            return
        }

        let slotId = slot.id ?? ""

        guard !slotId.isEmpty else {
            errorMessage = "予約時間枠IDが空です"
            return
        }

        isBooking = true
        errorMessage = ""
        successMessage = ""

        let eventRef = db
            .collection("organizations")
            .document(organizationId)
            .collection("bookingEvents")
            .document(eventId)

        let slotRef = eventRef
            .collection("slots")
            .document(slotId)

        let bookingRef = slotRef
            .collection("bookings")
            .document(uid)

        db.runTransaction({ transaction, errorPointer in

            do {
                let slotSnapshot = try transaction.getDocument(slotRef)
                let slotData = slotSnapshot.data() ?? [:]

                let isOpen = slotData["isOpen"] as? Bool ?? true
                let capacity = slotData["capacity"] as? Int ?? 0
                let reservedCount = slotData["reservedCount"] as? Int ?? 0

                if !isOpen {
                    errorPointer?.pointee = NSError(
                        domain: "BookingError",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "この時間枠は受付停止中です。"]
                    )
                    return nil
                }

                if reservedCount >= capacity {
                    errorPointer?.pointee = NSError(
                        domain: "BookingError",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "この時間枠は満席です。"]
                    )
                    return nil
                }

                let existingBooking = try transaction.getDocument(bookingRef)

                if existingBooking.exists {
                    errorPointer?.pointee = NSError(
                        domain: "BookingError",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "この時間枠はすでに予約済みです。"]
                    )
                    return nil
                }

                transaction.setData([
                    "organizationId": organizationId,
                    "eventId": eventId,
                    "slotId": slotId,
                    "memberUid": uid,
                    "status": "reserved",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: bookingRef)

                transaction.updateData([
                    "reservedCount": FieldValue.increment(Int64(1)),
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: slotRef)

                return nil

            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

        }) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }

                self.isBooking = false

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    print("❌ booking failed:", error.localizedDescription)
                    return
                }

                self.successMessage = "予約が完了しました。"
                print("✅ booking success")
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
