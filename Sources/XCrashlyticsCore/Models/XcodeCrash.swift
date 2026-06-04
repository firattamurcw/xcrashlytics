//
//  XcodeCrash.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation

/// A `CrashRecord` parsed from a local Xcode crash file, paired with its file
/// metadata (path, mtime, size).
///
/// File metadata is kept separately from `CrashRecord` so the same `CrashRecord`
/// shape can come from either source without carrying filesystem fields for
/// Firebase-sourced crashes.
public struct XcodeCrash: Codable, Sendable, Hashable {
    /// The parsed crash event.
    public var event: CrashRecord
    /// Absolute path to the source `.crash` file.
    public var filePath: String
    /// File modification time — used to sort recent crashes first.
    public var fileMtime: Date
    /// File size in bytes.
    public var fileSize: Int

    public init(event: CrashRecord, filePath: String, fileMtime: Date, fileSize: Int) {
        self.event = event
        self.filePath = filePath
        self.fileMtime = fileMtime
        self.fileSize = fileSize
    }

    /// CLI-facing id prefixed with `XC-` so Xcode-sourced crashes are easy to
    /// distinguish from Firebase ones at a glance.
    public var localId: String {
        "XC-\(event.id)"
    }
}
