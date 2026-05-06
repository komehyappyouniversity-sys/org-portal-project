//
//  MemberVideoItem.swift
//  blog.k100
//

import Foundation
import FirebaseFirestore

struct MemberVideoItem: Identifiable, Equatable {
    let id: String
    let title: String
    let url: String
    let thumbnailUrl: String
    let vimeoVideoId: String
    let isPublished: Bool
    let isMembersOnly: Bool
    let isPremium: Bool
    let price: Int
    let priceText: String
    let billingType: String
    let createdAt: Date?

    var playURL: String {
        if !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url
        }

        if !vimeoVideoId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "https://vimeo.com/\(vimeoVideoId)"
        }

        return ""
    }

    var displayPriceText: String {
        let trimmedPriceText = priceText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedPriceText.isEmpty {
            return trimmedPriceText
        }

        if price > 0 {
            if billingType == "monthly" {
                return "月額 \(price)円"
            } else {
                return "1本 \(price)円"
            }
        }

        return ""
    }

    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]

        guard let title = data["title"] as? String else {
            return nil
        }

        self.id = document.documentID
        self.title = title
        self.url = data["url"] as? String ?? ""
        self.thumbnailUrl = data["thumbnailUrl"] as? String ?? ""
        self.vimeoVideoId = data["vimeoVideoId"] as? String ?? document.documentID
        self.isPublished = data["isPublished"] as? Bool ?? false
        self.isMembersOnly = data["isMembersOnly"] as? Bool ?? false
        self.isPremium = data["isPremium"] as? Bool ?? false
        self.price = data["price"] as? Int ?? 0
        self.priceText = data["priceText"] as? String ?? ""
        self.billingType = data["billingType"] as? String ?? ""

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = nil
        }
    }
}
