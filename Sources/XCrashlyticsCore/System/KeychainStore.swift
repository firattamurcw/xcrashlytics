//
//  KeychainStore.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation
import Security

/// Errors raised by `KeychainStore` operations.
public enum KeychainError: Error, Equatable, Sendable {
    /// No item exists for the given `(service, account)` pair.
    case notFound
    /// Security.framework returned an unexpected `OSStatus`.
    case unexpectedStatus(OSStatus)
    /// Value could not be UTF-8 encoded/decoded.
    case encodingFailed
}

/// Abstraction over the macOS Keychain for storing sensitive secrets.
///
/// Each entry is keyed by `(service, account)`. Tests use
/// `InMemoryKeychainStore`; production uses `SystemKeychainStore`, which
/// reads/writes the user's login keychain via Security.framework.
public protocol KeychainStore: Sendable {
    /// Reads the stored value, or throws `KeychainError.notFound`.
    func read(service: String, account: String) throws -> String
    /// Writes (creating or replacing) the value for the given key pair.
    func write(_ value: String, service: String, account: String) throws
    /// Deletes the entry if present; no-op otherwise.
    func delete(service: String, account: String) throws
}

/// Production `KeychainStore` impl backed by Security.framework.
public struct SystemKeychainStore: KeychainStore {
    public init() {}

    public func read(service: String, account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let s = String(data: data, encoding: .utf8) else {
                throw KeychainError.encodingFailed
            }
            return s
        case errSecItemNotFound:
            throw KeychainError.notFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func write(_ value: String, service: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        // Try update first — handles the existing-entry case without a
        // delete-then-add gap that could lose data if the process crashed
        // between the two calls.
        let updateAttrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(updateStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    public func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
