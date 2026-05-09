import Foundation
import FirebaseFirestore

struct AdminFeatureSettings {
    var bookingEnabled: Bool
    var videoEnabled: Bool
    var paidVideoEnabled: Bool
    var messageEnabled: Bool
    var announcementEnabled: Bool
    var memberPostEnabled: Bool
    var categoryEnabled: Bool
    var scheduleEnabled: Bool

    static let `default` = AdminFeatureSettings(
        bookingEnabled: false,
        videoEnabled: false,
        paidVideoEnabled: false,
        messageEnabled: false,
        announcementEnabled: false,
        memberPostEnabled: false,
        categoryEnabled: false,
        scheduleEnabled: false
    )

    init(
        bookingEnabled: Bool,
        videoEnabled: Bool,
        paidVideoEnabled: Bool,
        messageEnabled: Bool,
        announcementEnabled: Bool,
        memberPostEnabled: Bool,
        categoryEnabled: Bool,
        scheduleEnabled: Bool
    ) {
        self.bookingEnabled = bookingEnabled
        self.videoEnabled = videoEnabled
        self.paidVideoEnabled = paidVideoEnabled
        self.messageEnabled = messageEnabled
        self.announcementEnabled = announcementEnabled
        self.memberPostEnabled = memberPostEnabled
        self.categoryEnabled = categoryEnabled
        self.scheduleEnabled = scheduleEnabled
    }

    init(data: [String: Any]) {
        self.bookingEnabled = data["bookingEnabled"] as? Bool ?? false
        self.videoEnabled = data["videoEnabled"] as? Bool ?? false
        self.paidVideoEnabled = data["paidVideoEnabled"] as? Bool ?? false
        self.messageEnabled = data["messageEnabled"] as? Bool ?? false
        self.announcementEnabled = data["announcementEnabled"] as? Bool ?? false
        self.memberPostEnabled = data["memberPostEnabled"] as? Bool ?? false
        self.categoryEnabled = data["categoryEnabled"] as? Bool ?? false
        self.scheduleEnabled = data["scheduleEnabled"] as? Bool ?? false
    }

    var asDictionary: [String: Any] {
        [
            "bookingEnabled": bookingEnabled,
            "videoEnabled": videoEnabled,
            "paidVideoEnabled": paidVideoEnabled,
            "messageEnabled": messageEnabled,
            "announcementEnabled": announcementEnabled,
            "memberPostEnabled": memberPostEnabled,
            "categoryEnabled": categoryEnabled,
            "scheduleEnabled": scheduleEnabled
        ]
    }
}
