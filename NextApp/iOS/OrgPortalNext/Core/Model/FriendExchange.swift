import Foundation

public struct FriendContact: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var userId: String
    public var name: String
    public var postalCode: String
    public var prefecture: String
    public var city: String
    public var addressLine: String
    public var birthDate: Date?
    public var phoneNumber: String
    public var email: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        userId: String,
        name: String,
        postalCode: String = "",
        prefecture: String = "",
        city: String = "",
        addressLine: String = "",
        birthDate: Date? = nil,
        phoneNumber: String = "",
        email: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.postalCode = postalCode
        self.prefecture = prefecture
        self.city = city
        self.addressLine = addressLine
        self.birthDate = birthDate
        self.phoneNumber = phoneNumber
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func validated(now: Date = .now, calendar: Calendar = .current) throws -> FriendContact {
        var result = self
        result.name = name.trimmed
        result.postalCode = postalCode.trimmed
        result.prefecture = prefecture.trimmed
        result.city = city.trimmed
        result.addressLine = addressLine.trimmed
        result.phoneNumber = phoneNumber.trimmed
        result.email = email.trimmed
        result.birthDate = birthDate.map(calendar.startOfDay(for:))
        result.updatedAt = now

        guard !result.name.isEmpty else {
            throw FriendExchangeValidationError.nameRequired
        }
        return result
    }
}

public struct FriendInteractionHistory: Identifiable, Equatable, Codable, Sendable {
    public static let maximumPhotoCount = 2

    public var id: UUID
    public var friendId: UUID
    public var interactionDate: Date
    public var memo: String
    public var photoUrls: [String]
    public var isPhoneCall: Bool
    public var phoneNumber: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        friendId: UUID,
        interactionDate: Date = .now,
        memo: String = "",
        photoUrls: [String] = [],
        isPhoneCall: Bool = false,
        phoneNumber: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.friendId = friendId
        self.interactionDate = interactionDate
        self.memo = memo
        self.photoUrls = photoUrls
        self.isPhoneCall = isPhoneCall
        self.phoneNumber = phoneNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func validated(now: Date = .now) throws -> FriendInteractionHistory {
        var result = self
        result.memo = memo.trimmed
        result.phoneNumber = phoneNumber.trimmed
        result.updatedAt = now

        guard result.photoUrls.count <= Self.maximumPhotoCount else {
            throw FriendExchangeValidationError.tooManyPhotos
        }
        guard !result.memo.isEmpty || !result.photoUrls.isEmpty || result.isPhoneCall else {
            throw FriendExchangeValidationError.historyContentRequired
        }
        return result
    }
}

public enum FriendExchangeValidationError: Error, Equatable, Sendable {
    case nameRequired
    case historyContentRequired
    case tooManyPhotos

    public var localizationKey: String {
        switch self {
        case .nameRequired: "error.friend_exchange.name_required"
        case .historyContentRequired: "error.friend_exchange.history_content_required"
        case .tooManyPhotos: "error.friend_exchange.too_many_photos"
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
