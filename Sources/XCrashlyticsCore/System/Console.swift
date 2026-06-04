//
//  Console.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation

/// Where command output and diagnostics go. Production writes to the real
/// streams; tests can inject `RecordingConsole` to capture writes.
public protocol CLIConsole: Sendable {
    /// Writes to stdout verbatim (no newline appended).
    func output(_ text: String)
    /// Writes "warning: <message>\n" to stderr.
    func warn(_ message: String)
    /// Writes "error: <message>\n" to stderr.
    func error(_ message: String)
}

public struct StandardConsole: CLIConsole {
    public init() {}

    public func output(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    public func warn(_ message: String) {
        FileHandle.standardError.write(Data("warning: \(message)\n".utf8))
    }

    public func error(_ message: String) {
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    }
}

/// Test double that records everything written.
public final class RecordingConsole: CLIConsole, @unchecked Sendable {
    public private(set) var outputs: [String] = []
    public private(set) var warnings: [String] = []
    public private(set) var errors: [String] = []

    public init() {}

    public func output(_ text: String) { outputs.append(text) }
    public func warn(_ message: String) { warnings.append(message) }
    public func error(_ message: String) { errors.append(message) }
}
