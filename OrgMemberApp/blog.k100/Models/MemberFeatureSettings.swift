import Foundation

struct MemberFeatureSettings {

    var bookingEnabled: Bool
    var videoEnabled: Bool
    var paidVideoEnabled: Bool
    var announcementEnabled: Bool
    var scheduleEnabled: Bool
    var memberPostEnabled: Bool

    static let `default` = MemberFeatureSettings(
        bookingEnabled: true,
        videoEnabled: true,
        paidVideoEnabled: true,
        announcementEnabled: true,
        scheduleEnabled: true,
        memberPostEnabled: true
    )

    init(
        bookingEnabled: Bool,
        videoEnabled: Bool,
        paidVideoEnabled: Bool,
        announcementEnabled: Bool,
        scheduleEnabled: Bool,
        memberPostEnabled: Bool
    ) {
        self.bookingEnabled = bookingEnabled
        self.videoEnabled = videoEnabled
        self.paidVideoEnabled = paidVideoEnabled
        self.announcementEnabled = announcementEnabled
        self.scheduleEnabled = scheduleEnabled
        self.memberPostEnabled = memberPostEnabled
    }

    init(data: [String: Any]) {
        self.bookingEnabled = data["bookingEnabled"] as? Bool ?? true
        self.videoEnabled = data["videoEnabled"] as? Bool ?? true
        self.paidVideoEnabled = data["paidVideoEnabled"] as? Bool ?? true
        self.announcementEnabled = data["announcementEnabled"] as? Bool ?? true
        self.scheduleEnabled = data["scheduleEnabled"] as? Bool ?? true
        self.memberPostEnabled = data["memberPostEnabled"] as? Bool ?? true
    }
}
