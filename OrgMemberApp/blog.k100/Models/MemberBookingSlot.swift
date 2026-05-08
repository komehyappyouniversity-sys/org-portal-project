//
//  MemberBookingSlot.swift
//  blog.k100
//

import Foundation

struct MemberBookingSlot: Identifiable {

    var id: String?

    var startAt: Date
    var endAt: Date

    var capacity: Int
    var reservedCount: Int
    var paidCount: Int

    var isOpen: Bool

    var createdAt: Date?
    var updatedAt: Date?

    var remainingCount: Int {
        max(capacity - reservedCount, 0)
    }

    var isFull: Bool {
        reservedCount >= capacity
    }

    var canReserve: Bool {
        isOpen && !isFull
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
