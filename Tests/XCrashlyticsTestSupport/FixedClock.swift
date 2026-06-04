//
//  FixedClock.swift
//  xcrashlyticsTests
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation
import XCrashlyticsCore

/// `Clock` test double — returns the same `Date` until tests advance it.
public final class FixedClock: Clock, @unchecked Sendable {
    private var current: Date

    public init(_ initial: Date = Date(timeIntervalSince1970: 1_000_000)) {
        self.current = initial
    }

    public func now() -> Date { current }

    /// Advances the clock by `seconds`.
    public func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}
