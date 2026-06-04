//
//  MockTokenProvider.swift
//  xcrashlyticsTests
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation
import XCrashlyticsCore

/// `AccessTokenProvider` test double.
public final class MockTokenProvider: AccessTokenProvider, @unchecked Sendable {
    public private(set) var tokenCalls = 0
    public private(set) var forceRefreshCalls = 0
    public var nextTokens: [String]

    public init(tokens: [String] = ["AT"]) {
        self.nextTokens = tokens
    }

    public func token() async throws -> String {
        tokenCalls += 1
        if nextTokens.count > 1 {
            return nextTokens.removeFirst()
        }
        return nextTokens.first ?? "AT"
    }

    public func forceRefresh() async throws -> String {
        forceRefreshCalls += 1
        if nextTokens.count > 1 {
            return nextTokens.removeFirst()
        }
        return nextTokens.first ?? "AT"
    }
}
