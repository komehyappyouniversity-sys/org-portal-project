//
//  MemberBookingSlot.swift
//  blog.k100
//

import Foundation

struct MemberBookingSlot: Identifiable, Equatable {
    let id: String?

    let startAt: Date
    let endAt: Date

    let capacity: Int
    let reservedCount: Int
    let paidCount: Int

    let isOpen: Bool
}
