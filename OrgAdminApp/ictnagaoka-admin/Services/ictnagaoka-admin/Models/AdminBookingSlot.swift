//
//  AdminBookingSlot.swift
//  ictnagaoka-admin
//

import Foundation
import FirebaseFirestore

struct AdminBookingSlot: Identifiable, Codable {
    @DocumentID var id: String?

    var startAt: Date
    var endAt: Date

    var capacity: Int
    var reservedCount: Int
    var paidCount: Int

    var isOpen: Bool

    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: String? = nil,
        startAt: Date = Date(),
        endAt: Date = Date().addingTimeInterval(60 * 60),
        capacity: Int = 1,
        reservedCount: Int = 0,
        paidCount: Int = 0,
        isOpen: Bool = true,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.startAt = startAt
        self.endAt = endAt
        self.capacity = capacity
        self.reservedCount = reservedCount
        self.paidCount = paidCount
        self.isOpen = isOpen
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var remainingCount: Int {
        max(capacity - reservedCount, 0)
    }

    var isFull: Bool {
        reservedCount >= capacity
    }

    var displayStatus: String {
        if !isOpen {
            return "受付停止"
        }

        if isFull {
            return "満席"
        }

        return "受付中"
    }
}
