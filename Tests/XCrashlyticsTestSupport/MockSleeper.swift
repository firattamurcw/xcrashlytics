//
//  MockSleeper.swift
//  xcrashlyticsTests
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation
import XCrashlyticsCore

/// `Sleeper` test double — records delays without actually sleeping.
public final class MockSleeper: Sleeper, @unchecked Sendable {
    public private(set) var delays: [Double] = []

    public init() {}

    public func sleep(seconds: Double) async throws {
        delays.append(seconds)
    }
}
