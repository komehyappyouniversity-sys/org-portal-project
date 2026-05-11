import Foundation

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
        bookingEnabled: true,
        videoEnabled: true,
        paidVideoEnabled: true,
        messageEnabled: true,
        announcementEnabled: true,
        memberPostEnabled: true,
        categoryEnabled: true,
        scheduleEnabled: true
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

        self.bookingEnabled =
        data["bookingEnabled"] as? Bool ?? true

        self.videoEnabled =
        data["videoEnabled"] as? Bool ?? true

        self.paidVideoEnabled =
        data["paidVideoEnabled"] as? Bool ?? true

        self.messageEnabled =
        data["messageEnabled"] as? Bool ?? true

        self.announcementEnabled =
        data["announcementEnabled"] as? Bool ?? true

        self.memberPostEnabled =
        data["memberPostEnabled"] as? Bool ?? true

        self.categoryEnabled =
        data["categoryEnabled"] as? Bool ?? true

        self.scheduleEnabled =
        data["scheduleEnabled"] as? Bool ?? true
    }
}
