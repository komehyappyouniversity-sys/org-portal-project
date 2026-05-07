//
//  AdminBookingEvent.swift
//  ictnagaoka-admin
//

import Foundation

struct AdminBookingEvent: Identifiable {
    var id: String?

    var title: String
    var description: String
    var eventDate: Date

    var feeAmount: Int
    var appStoreProductId: String

    var paymentRequired: Bool
    var zoomURL: String

    var isPublished: Bool

    var createdAt: Date?
    var updatedAt: Date?
}
