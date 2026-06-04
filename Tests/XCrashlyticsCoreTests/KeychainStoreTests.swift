//
//  KeychainStoreTests.swift
//  xcrashlyticsTests
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Testing
@testable import XCrashlyticsCore
import XCrashlyticsTestSupport

@Suite("KeychainStore protocol contract")
struct KeychainStoreTests {
    @Test("write then read returns value")
    func writeRead() throws {
        let kc = InMemoryKeychainStore()
        try kc.write("token-abc", service: "com.xcrashlytics.test", account: "user")
        let v = try kc.read(service: "com.xcrashlytics.test", account: "user")
        #expect(v == "token-abc")
    }

    @Test("read missing throws notFound")
    func readMissing() {
        let kc = InMemoryKeychainStore()
        #expect(throws: KeychainError.notFound) {
            _ = try kc.read(service: "x", account: "y")
        }
    }

    @Test("delete removes value")
    func deleteRemoves() throws {
        let kc = InMemoryKeychainStore()
        try kc.write("v", service: "s", account: "a")
        try kc.delete(service: "s", account: "a")
        #expect(throws: KeychainError.notFound) {
            _ = try kc.read(service: "s", account: "a")
        }
    }

    @Test("delete missing is idempotent")
    func deleteMissingIdempotent() throws {
        let kc = InMemoryKeychainStore()
        try kc.delete(service: "s", account: "a")
    }
}
