import Foundation
import Security

enum SecretStore {
    private static let service = "io.github.lemkyz.holdlet"
    static func get(_ account: String) throws -> String? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword,
            kSecAttrService: service, kSecAttrAccount: account,
            kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne] as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw SecretError.operation(status) }
        return String(data: data, encoding: .utf8)
    }
    static func set(_ value: String, for account: String) throws {
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                     kSecAttrAccount: account] as CFDictionary
        let data = Data(value.utf8)
        let status = SecItemUpdate(query, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            let added = SecItemAdd([kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                kSecAttrAccount: account, kSecValueData: data,
                kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly] as CFDictionary, nil)
            guard added == errSecSuccess else { throw SecretError.operation(added) }
        } else if status != errSecSuccess { throw SecretError.operation(status) }
    }
    static func delete(_ account: String) throws {
        let status = SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                                   kSecAttrAccount: account] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecretError.operation(status) }
    }
    enum SecretError: LocalizedError {
        case operation(OSStatus)
        var errorDescription: String? { "Keychain could not be accessed. Unlock your Mac and try again." }
    }
}
