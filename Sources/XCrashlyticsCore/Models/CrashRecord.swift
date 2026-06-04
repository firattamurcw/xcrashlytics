//
//  CrashRecord.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation

/// A single crash event — the shared shape used across both `.xcode` and
/// `.firebase` sources.
///
/// Holds the crashed thread's frames, binary images for symbolication, and
/// metadata about the device/app.
public struct CrashRecord: Codable, Sendable, Hashable {
    /// Source-specific identifier (Firebase issue id, or local incident UUID).
    public var id: String
    /// Where this crash came from.
    public var source: CrashSource
    /// App bundle identifier (e.g. `com.example.MyApp`).
    public var bundleId: String?
    /// `CFBundleVersion` build number.
    public var bundleVersion: String?
    /// OS version string (e.g. `iPhone OS 17.0 (21A329)`).
    public var osVersion: String?
    /// Hardware model code (e.g. `iPhone14,2`).
    public var deviceModel: String?
    /// Number of the thread that triggered the crash, as reported by the log.
    public var crashedThreadIndex: Int
    /// Exception summary.
    public var exception: ExceptionInfo
    /// Frames of the crashed thread.
    public var frames: [Frame]
    /// All loaded binaries at crash time — keyed by `imageUUID` for symbolication.
    public var binaryImages: [BinaryImage]
    /// Wall-clock time the crash occurred, if recorded.
    public var timestamp: Date?
    /// Original file path the report was parsed from (only set for `.xcode`).
    public var rawPath: String?
    /// Total number of crash events observed (Firebase only).
    public var eventsCount: Int?
    /// Number of unique impacted users (Firebase only).
    public var impactedUsersCount: Int?
    /// Version the issue was first seen in (Firebase only). `bundleVersion`
    /// holds the last-seen version, falling back to this when absent.
    public var firstSeenVersion: String?
    /// Version the issue was last seen in (Firebase only).
    public var lastSeenVersion: String?

    public init(
        id: String,
        source: CrashSource,
        bundleId: String? = nil,
        bundleVersion: String? = nil,
        osVersion: String? = nil,
        deviceModel: String? = nil,
        crashedThreadIndex: Int,
        exception: ExceptionInfo,
        frames: [Frame],
        binaryImages: [BinaryImage] = [],
        timestamp: Date? = nil,
        rawPath: String? = nil,
        eventsCount: Int? = nil,
        impactedUsersCount: Int? = nil,
        firstSeenVersion: String? = nil,
        lastSeenVersion: String? = nil
    ) {
        self.id = id
        self.source = source
        self.bundleId = bundleId
        self.bundleVersion = bundleVersion
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.crashedThreadIndex = crashedThreadIndex
        self.exception = exception
        self.frames = frames
        self.binaryImages = binaryImages
        self.timestamp = timestamp
        self.rawPath = rawPath
        self.eventsCount = eventsCount
        self.impactedUsersCount = impactedUsersCount
        self.firstSeenVersion = firstSeenVersion
        self.lastSeenVersion = lastSeenVersion
    }
}
