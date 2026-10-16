import Foundation
import Security

enum SecretStore {
    private static let service = "io.github.lemkyz.holdlet"
    private static let executor = BlockingOperationExecutor()
    static func get(_ account: String) async throws -> String? {
        try await executor.run(timeout: 8) { try read(account) }
    }
    static func set(_ value: String, for account: String) async throws {
        try await executor.run { try write(value, for: account) }
    }
    static func replace(_ value: String, for account: String, matching expected: String) async throws {
        try await executor.run {
            guard try read(account) == expected else { throw CancellationError() }
            try write(value, for: account)
        }
    }
    static func delete(_ account: String) async throws {
        try await executor.run { try remove(account) }
    }
    static func delete(_ account: String, matching expected: String) async throws {
        try await executor.run {
            if try read(account) == expected { try remove(account) }
        }
    }
    private static func read(_ account: String) throws -> String? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword,
            kSecAttrService: service, kSecAttrAccount: account,
            kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne] as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw SecretError.operation(status) }
        return String(data: data, encoding: .utf8)
    }
    private static func write(_ value: String, for account: String) throws {
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
    private static func remove(_ account: String) throws {
        let status = SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                                   kSecAttrAccount: account] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecretError.operation(status) }
    }
    enum SecretError: LocalizedError {
        case operation(OSStatus)
        var errorDescription: String? { "Keychain could not be accessed. Unlock your Mac and try again." }
    }
}
