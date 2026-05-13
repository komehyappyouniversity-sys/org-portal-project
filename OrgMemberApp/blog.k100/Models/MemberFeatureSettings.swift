import Foundation

struct MemberFeatureSettings {

    var bookingEnabled: Bool
    var videoEnabled: Bool
    var paidVideoEnabled: Bool

    // 公開お知らせ：未会員向け
    var publicAnnouncementEnabled: Bool

    // 会員向けお知らせ：一斉送信・会員ページ用
    var memberMessageEnabled: Bool

    var scheduleEnabled: Bool
    var memberPostEnabled: Bool

    // 旧コード互換用
    var announcementEnabled: Bool {
        publicAnnouncementEnabled
    }

    static let `default` = MemberFeatureSettings(
        bookingEnabled: true,
        videoEnabled: true,
        paidVideoEnabled: true,
        publicAnnouncementEnabled: true,
        memberMessageEnabled: true,
        scheduleEnabled: true,
        memberPostEnabled: true
    )

    init(
        bookingEnabled: Bool,
        videoEnabled: Bool,
        paidVideoEnabled: Bool,
        publicAnnouncementEnabled: Bool,
        memberMessageEnabled: Bool,
        scheduleEnabled: Bool,
        memberPostEnabled: Bool
    ) {
        self.bookingEnabled = bookingEnabled
        self.videoEnabled = videoEnabled
        self.paidVideoEnabled = paidVideoEnabled
        self.publicAnnouncementEnabled = publicAnnouncementEnabled
        self.memberMessageEnabled = memberMessageEnabled
        self.scheduleEnabled = scheduleEnabled
        self.memberPostEnabled = memberPostEnabled
    }

    init(data: [String: Any]) {
        self.bookingEnabled = data["bookingEnabled"] as? Bool ?? true
        self.videoEnabled = data["videoEnabled"] as? Bool ?? true
        self.paidVideoEnabled = data["paidVideoEnabled"] as? Bool ?? true

        // 新フィールドがあればそれを優先
        self.publicAnnouncementEnabled =
            data["publicAnnouncementEnabled"] as? Bool
            ?? data["announcementEnabled"] as? Bool
            ?? true

        // 会員向けお知らせは、旧 announcementEnabled とは切り離す
        self.memberMessageEnabled =
            data["memberMessageEnabled"] as? Bool
            ?? true

        self.scheduleEnabled = data["scheduleEnabled"] as? Bool ?? true
        self.memberPostEnabled = data["memberPostEnabled"] as? Bool ?? true
    }
}
