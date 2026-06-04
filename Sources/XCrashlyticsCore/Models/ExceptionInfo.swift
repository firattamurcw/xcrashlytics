//
//  ExceptionInfo.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation

/// Top-level "what killed the process" summary extracted from a crash report.
public struct ExceptionInfo: Codable, Sendable, Hashable {
    /// Mach exception type (e.g. `EXC_BAD_ACCESS`, `EXC_CRASH`).
    public var exceptionType: String
    /// POSIX signal that delivered the kill (e.g. `SIGSEGV`, `SIGABRT`).
    public var signal: String?
    /// Optional subtype detail (e.g. `KERN_INVALID_ADDRESS at 0x0...`).
    public var subtype: String?
    /// Free-form description (unused by the `.crash` parser; Firebase fills it).
    public var description: String?

    public init(
        exceptionType: String,
        signal: String? = nil,
        subtype: String? = nil,
        description: String? = nil
    ) {
        self.exceptionType = exceptionType
        self.signal = signal
        self.subtype = subtype
        self.description = description
    }
}
