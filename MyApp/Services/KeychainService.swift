import Foundation
import Security

enum KeychainServiceError: LocalizedError {
    case unexpectedData
    case status(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedData: "The saved credential could not be read."
        case let .status(status):
            SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)."
        }
    }
}

struct KeychainService {
    private let service = "com.captain21.filebridge.sftp"

    func password(for profile: SFTPConnectionProfile) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profile.passwordKeychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainServiceError.status(status) }
        guard let data = item as? Data, let password = String(data: data, encoding: .utf8) else {
            throw KeychainServiceError.unexpectedData
        }
        return password
    }

    func save(password: String, for profile: SFTPConnectionProfile) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profile.passwordKeychainAccount
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(password.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            let addStatus = SecItemAdd((query.merging(attributes) { _, new in new }) as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainServiceError.status(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw KeychainServiceError.status(updateStatus)
        }
    }

    func deletePassword(for profile: SFTPConnectionProfile) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profile.passwordKeychainAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainServiceError.status(status)
        }
    }
}
