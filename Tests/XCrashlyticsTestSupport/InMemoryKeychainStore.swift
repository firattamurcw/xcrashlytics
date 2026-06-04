//
//  InMemoryKeychainStore.swift
//  xcrashlyticsTests
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation
import XCrashlyticsCore

/// In-RAM `KeychainStore` impl for tests.
///
/// Storage is a `[String: String]` keyed by `"service::account"`. Mirrors the
/// real keychain's contract — `read` of an absent key throws `.notFound`,
/// `delete` of an absent key is a no-op.
public final class InMemoryKeychainStore: KeychainStore, @unchecked Sendable {
    private var storage: [String: String] = [:]
    public init() {}

    private func key(_ service: String, _ account: String) -> String {
        "\(service)::\(account)"
    }

    public func read(service: String, account: String) throws -> String {
        guard let v = storage[key(service, account)] else {
            throw KeychainError.notFound
        }
        return v
    }

    public func write(_ value: String, service: String, account: String) throws {
        storage[key(service, account)] = value
    }

    public func delete(service: String, account: String) throws {
        storage.removeValue(forKey: key(service, account))
    }
}
