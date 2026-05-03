//
//  ScheduleEvent.swift
//  blog.k100
//
//  Created by 根津浩 on 2026/04/14.
//

import Foundation
import FirebaseFirestore

struct ScheduleEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startAt: Date
    let endAt: Date?
    let locationName: String
    let notes: String
    let createdAt: Date?

    init(
        id: String,
        title: String,
        startAt: Date,
        endAt: Date? = nil,
        locationName: String = "",
        notes: String = "",
        createdAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.locationName = locationName
        self.notes = notes
        self.createdAt = createdAt
    }

    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]

        guard
            let title = data["title"] as? String,
            let startTimestamp = data["startAt"] as? Timestamp
        else {
            return nil
        }

        let endTimestamp = data["endAt"] as? Timestamp
        let locationName = data["locationName"] as? String ?? ""
        let notes = data["notes"] as? String ?? ""
        let createdTimestamp = data["createdAt"] as? Timestamp

        self.id = document.documentID
        self.title = title
        self.startAt = startTimestamp.dateValue()
        self.endAt = endTimestamp?.dateValue()
        self.locationName = locationName
        self.notes = notes
        self.createdAt = createdTimestamp?.dateValue()
    }
}
