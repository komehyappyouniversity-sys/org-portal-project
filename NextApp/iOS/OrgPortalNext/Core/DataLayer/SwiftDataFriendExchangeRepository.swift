import Foundation
import Model
import SwiftData

@Model
public final class FriendContactRecord {
    @Attribute(.unique) public var id: UUID
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

    public init(contact: FriendContact) {
        id = contact.id
        userId = contact.userId
        name = contact.name
        postalCode = contact.postalCode
        prefecture = contact.prefecture
        city = contact.city
        addressLine = contact.addressLine
        birthDate = contact.birthDate
        phoneNumber = contact.phoneNumber
        email = contact.email
        createdAt = contact.createdAt
        updatedAt = contact.updatedAt
    }

    public func update(from contact: FriendContact) {
        userId = contact.userId
        name = contact.name
        postalCode = contact.postalCode
        prefecture = contact.prefecture
        city = contact.city
        addressLine = contact.addressLine
        birthDate = contact.birthDate
        phoneNumber = contact.phoneNumber
        email = contact.email
        updatedAt = contact.updatedAt
    }

    public func domainModel() -> FriendContact {
        FriendContact(
            id: id,
            userId: userId,
            name: name,
            postalCode: postalCode,
            prefecture: prefecture,
            city: city,
            addressLine: addressLine,
            birthDate: birthDate,
            phoneNumber: phoneNumber,
            email: email,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
public final class FriendInteractionHistoryRecord {
    @Attribute(.unique) public var id: UUID
    public var friendId: UUID
    public var interactionDate: Date
    public var memoText: String
    public var photoUrlsData: Data
    public var isPhoneCall: Bool
    public var phoneNumber: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(history: FriendInteractionHistory) {
        id = history.id
        friendId = history.friendId
        interactionDate = history.interactionDate
        memoText = history.memo
        photoUrlsData = Self.encode(history.photoUrls)
        isPhoneCall = history.isPhoneCall
        phoneNumber = history.phoneNumber
        createdAt = history.createdAt
        updatedAt = history.updatedAt
    }

    public func update(from history: FriendInteractionHistory) {
        friendId = history.friendId
        interactionDate = history.interactionDate
        memoText = history.memo
        photoUrlsData = Self.encode(history.photoUrls)
        isPhoneCall = history.isPhoneCall
        phoneNumber = history.phoneNumber
        updatedAt = history.updatedAt
    }

    public func domainModel() -> FriendInteractionHistory {
        FriendInteractionHistory(
            id: id,
            friendId: friendId,
            interactionDate: interactionDate,
            memo: memoText,
            photoUrls: Self.decode(photoUrlsData),
            isPhoneCall: isPhoneCall,
            phoneNumber: phoneNumber,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func encode(_ values: [String]) -> Data {
        (try? JSONEncoder().encode(values)) ?? Data("[]".utf8)
    }

    private static func decode(_ data: Data) -> [String] {
        (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

@MainActor
public final class SwiftDataFriendExchangeRepository: FriendExchangeRepository {
    private let context: ModelContext

    public init(modelContainer: ModelContainer) {
        context = modelContainer.mainContext
    }

    public func fetchContacts() async throws -> [FriendContact] {
        let descriptor = FetchDescriptor<FriendContactRecord>(
            sortBy: [SortDescriptor(\.name), SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.domainModel() }
    }

    public func fetchHistories(friendId: UUID) async throws -> [FriendInteractionHistory] {
        let id = friendId
        let descriptor = FetchDescriptor<FriendInteractionHistoryRecord>(
            predicate: #Predicate { $0.friendId == id },
            sortBy: [SortDescriptor(\.interactionDate, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.domainModel() }
    }

    public func save(_ contact: FriendContact) async throws {
        let validated = try contact.validated(now: contact.updatedAt)
        let id = validated.id
        let descriptor = FetchDescriptor<FriendContactRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: validated)
        } else {
            context.insert(FriendContactRecord(contact: validated))
        }
        try context.save()
    }

    public func save(_ history: FriendInteractionHistory) async throws {
        let validated = try history.validated(now: history.updatedAt)
        let id = validated.id
        let descriptor = FetchDescriptor<FriendInteractionHistoryRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: validated)
        } else {
            context.insert(FriendInteractionHistoryRecord(history: validated))
        }
        try context.save()
    }

    public func deleteContact(id: UUID) async throws {
        let contactId = id
        let contactDescriptor = FetchDescriptor<FriendContactRecord>(
            predicate: #Predicate { $0.id == contactId }
        )
        let historyDescriptor = FetchDescriptor<FriendInteractionHistoryRecord>(
            predicate: #Predicate { $0.friendId == contactId }
        )
        try context.fetch(contactDescriptor).forEach(context.delete)
        try context.fetch(historyDescriptor).forEach(context.delete)
        try context.save()
    }

    public func deleteHistory(id: UUID) async throws {
        let historyId = id
        let descriptor = FetchDescriptor<FriendInteractionHistoryRecord>(
            predicate: #Predicate { $0.id == historyId }
        )
        try context.fetch(descriptor).forEach(context.delete)
        try context.save()
    }
}
