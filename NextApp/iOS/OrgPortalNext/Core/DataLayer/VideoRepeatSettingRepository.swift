import Foundation
import Model
import Security

@MainActor
public protocol VideoRepeatSettingRepository {
    func setting(videoId: String) async throws -> VideoRepeatSetting?
    func save(_ setting: VideoRepeatSetting) async throws
}

@MainActor
public protocol GuestUserIdProvider {
    func guestUserId() throws -> String
}

@MainActor
public final class KeychainGuestUserIdProvider: GuestUserIdProvider {
    private let service: String
    private let account: String

    public init(
        service: String = "jp.komehyappyo.member.next.guest",
        account: String = "guest-user-id"
    ) {
        self.service = service
        self.account = account
    }

    public func guestUserId() throws -> String {
        if let stored = try read(), UUID(uuidString: stored) != nil {
            return stored
        }

        let generated = UUID().uuidString
        try save(generated)
        return generated
    }

    private func read() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainGuestUserIdError(status: status)
        }
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainGuestUserIdError(status: errSecDecode)
        }
        return value
    }

    private func save(_ value: String) throws {
        let data = Data(value.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainGuestUserIdError(status: updateStatus)
        }

        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainGuestUserIdError(status: status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

private struct KeychainGuestUserIdError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error: \(status)"
    }
}
