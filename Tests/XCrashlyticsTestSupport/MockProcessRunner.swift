//
//  MockProcessRunner.swift
//  xcrashlyticsTests
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation
import XCrashlyticsCore

/// Scripted `ProcessRunner` for tests.
///
/// Test sets up a closure that maps `(executable, arguments)` to a
/// `ProcessResult`. Default behavior is to throw — forces every test path to
/// be explicit about what subprocess calls it expects.
public final class MockProcessRunner: ProcessRunner, @unchecked Sendable {
    /// `(executable, arguments) -> ProcessResult` lookup. Return `nil` to
    /// fall back to the throw-on-miss default.
    public var handler: ((String, [String]) -> ProcessResult?)?
    /// History of every invocation — useful for asserting "was atos called".
    public private(set) var calls: [(String, [String])] = []

    public init(handler: ((String, [String]) -> ProcessResult?)? = nil) {
        self.handler = handler
    }

    public func run(executable: String, arguments: [String], stdin: String?) throws -> ProcessResult {
        calls.append((executable, arguments))
        if let result = handler?(executable, arguments) {
            return result
        }
        throw NSError(
            domain: "MockProcessRunner",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "no handler for \(executable) \(arguments)"]
        )
    }
}
