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
    @Published var myBookedSlotIds: Set<String> = []

    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var successMessage = ""

    @Published var processingSlotId: String?

    var isProcessing: Bool {
        processingSlotId != nil
    }

    private let db = Firestore.firestore()

    private var slotListener: ListenerRegistration?
    private var bookingListeners: [ListenerRegistration] = []

    deinit {
        slotListener?.remove()
        bookingListeners.forEach { $0.remove() }
    }

    // MARK: - Listen

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

        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "ログイン情報を取得できませんでした"
            return
        }

        isLoading = true
        errorMessage = ""
        successMessage = ""

        stopListening()

        let eventRef = db
            .collection("organizations")
            .document(organizationId)
            .collection("bookingEvents")
            .document(eventId)

        slotListener = eventRef
            .collection("slots")
            .order(by: "startAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                Task { @MainActor in
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        print("❌ slot listen error:", error.localizedDescription)
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

                    self.listenMyBookings(
                        eventRef: eventRef,
                        slotIds: self.slots.compactMap { $0.id },
                        uid: uid
                    )

                    print("✅ slots loaded:", self.slots.count)
                }
            }
    }

    // MARK: - My Bookings

    private func listenMyBookings(
        eventRef: DocumentReference,
        slotIds: [String],
        uid: String
    ) {
        bookingListeners.forEach { $0.remove() }
        bookingListeners = []

        for slotId in slotIds {
            let listener = eventRef
                .collection("slots")
                .document(slotId)
                .collection("bookings")
                .document(uid)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self else { return }

                    Task { @MainActor in
                        if let error = error {
                            print("❌ booking listen error:", error.localizedDescription)
                            return
                        }

                        if snapshot?.exists == true {
                            self.myBookedSlotIds.insert(slotId)
                        } else {
                            self.myBookedSlotIds.remove(slotId)
                        }
                    }
                }

            bookingListeners.append(listener)
        }
    }

    // MARK: - Booking

    func book(
        organizationId: String,
        eventId: String,
        slot: MemberBookingSlot
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "ログイン情報を取得できませんでした"
            return
        }

        let slotId = slot.id ?? ""

        guard !organizationId.isEmpty, !eventId.isEmpty, !slotId.isEmpty else {
            errorMessage = "予約情報が不足しています"
            return
        }

        processingSlotId = slotId
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

        db.runTransaction { transaction, errorPointer in
            do {
                let slotSnapshot = try transaction.getDocument(slotRef)
                let data = slotSnapshot.data() ?? [:]

                let capacity = data["capacity"] as? Int ?? 0
                let reservedCount = data["reservedCount"] as? Int ?? 0
                let isOpen = data["isOpen"] as? Bool ?? true

                if !isOpen {
                    errorPointer?.pointee = NSError(
                        domain: "booking",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "受付停止中です"]
                    )
                    return nil
                }

                if reservedCount >= capacity {
                    errorPointer?.pointee = NSError(
                        domain: "booking",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "満席です"]
                    )
                    return nil
                }

                let bookingSnapshot = try transaction.getDocument(bookingRef)

                if bookingSnapshot.exists {
                    errorPointer?.pointee = NSError(
                        domain: "booking",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "すでに予約済みです"]
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

        } completion: { [weak self] _, error in
            guard let self else { return }

            Task { @MainActor in
                self.processingSlotId = nil

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    print("❌ booking failed:", error.localizedDescription)
                    return
                }

                self.myBookedSlotIds.insert(slotId)
                self.updateLocalReservedCount(slotId: slotId, delta: 1)

                self.successMessage = "予約が完了しました"
                print("✅ booking success")
            }
        }
    }

    // MARK: - Cancel

    func cancelBooking(
        organizationId: String,
        eventId: String,
        slot: MemberBookingSlot
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "ログイン情報を取得できませんでした"
            return
        }

        let slotId = slot.id ?? ""

        guard !organizationId.isEmpty, !eventId.isEmpty, !slotId.isEmpty else {
            errorMessage = "キャンセル情報が不足しています"
            return
        }

        processingSlotId = slotId
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

        db.runTransaction { transaction, errorPointer in
            do {
                let bookingSnapshot = try transaction.getDocument(bookingRef)

                if !bookingSnapshot.exists {
                    errorPointer?.pointee = NSError(
                        domain: "cancel",
                        code: 10,
                        userInfo: [NSLocalizedDescriptionKey: "予約データがありません"]
                    )
                    return nil
                }

                let slotSnapshot = try transaction.getDocument(slotRef)
                let slotData = slotSnapshot.data() ?? [:]
                let reservedCount = slotData["reservedCount"] as? Int ?? 0

                transaction.deleteDocument(bookingRef)

                transaction.updateData([
                    "reservedCount": max(reservedCount - 1, 0),
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: slotRef)

                return nil

            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

        } completion: { [weak self] _, error in
            guard let self else { return }

            Task { @MainActor in
                self.processingSlotId = nil

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    print("❌ cancel failed:", error.localizedDescription)
                    return
                }

                self.myBookedSlotIds.remove(slotId)
                self.updateLocalReservedCount(slotId: slotId, delta: -1)

                self.successMessage = "予約をキャンセルしました"
                print("✅ cancel success")
            }
        }
    }

    // MARK: - Local Update

    private func updateLocalReservedCount(
        slotId: String,
        delta: Int
    ) {
        guard let index = slots.firstIndex(where: { $0.id == slotId }) else {
            return
        }

        let oldSlot = slots[index]
        let newReservedCount = max(oldSlot.reservedCount + delta, 0)

        slots[index] = MemberBookingSlot(
            id: oldSlot.id,
            startAt: oldSlot.startAt,
            endAt: oldSlot.endAt,
            capacity: oldSlot.capacity,
            reservedCount: newReservedCount,
            paidCount: oldSlot.paidCount,
            isOpen: oldSlot.isOpen
        )
    }

    // MARK: - Stop

    func stopListening() {
        slotListener?.remove()
        slotListener = nil

        bookingListeners.forEach { $0.remove() }
        bookingListeners = []
    }
}
