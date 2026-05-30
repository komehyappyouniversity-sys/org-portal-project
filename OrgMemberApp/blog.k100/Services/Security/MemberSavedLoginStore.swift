import Foundation
import Security

final class MemberSavedLoginStore {

    static let shared = MemberSavedLoginStore()

    private init() {}

    private let service = "blog.k100.member.savedLogin"

    private enum Account {
        static let email = "email"
        static let password = "password"
    }

    func save(email: String, password: String) {
        saveValue(email, account: Account.email)
        saveValue(password, account: Account.password)
    }

    func loadEmail() -> String {
        loadValue(account: Account.email) ?? ""
    }

    func loadPassword() -> String {
        loadValue(account: Account.password) ?? ""
    }

    func hasSavedLogin() -> Bool {
        !loadEmail().isEmpty && !loadPassword().isEmpty
    }

    func clear() {
        deleteValue(account: Account.email)
        deleteValue(account: Account.password)
    }

    private func saveValue(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        deleteValue(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadValue(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteValue(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
