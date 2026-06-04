//
//  Clock.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation

/// Time abstraction so tests can use a `FixedClock` and avoid wall-clock flakiness.
public protocol Clock: Sendable {
    /// Returns "now".
    func now() -> Date
}

/// Production `Clock` impl backed by the system wall clock.
public struct SystemClock: Clock {
    public init() {}
    public func now() -> Date { Date() }
}
