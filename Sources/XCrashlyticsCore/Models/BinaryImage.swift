//
//  BinaryImage.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation

/// A binary loaded into the crashed process — the app itself or any framework.
///
/// Each `Frame.address` is resolved by finding the image whose memory range
/// contains the address, then computing the slide:
/// `address - image.loadAddress = offset within binary`.
public struct BinaryImage: Codable, Sendable, Hashable {
    /// Binary name (e.g. `MyApp`, `UIKit`, `libsystem_c.dylib`).
    public var name: String
    /// 16-byte UUID identifying the exact build — must match the dSYM's UUID.
    public var uuid: String
    /// Address where the binary was loaded in process memory.
    public var loadAddress: UInt64
    /// CPU architecture (`arm64`, `x86_64`) — required by `atos`.
    public var arch: String
    /// Original on-disk path of the binary on the device that crashed.
    public var path: String

    public init(
        name: String,
        uuid: String,
        loadAddress: UInt64,
        arch: String,
        path: String
    ) {
        self.name = name
        self.uuid = uuid
        self.loadAddress = loadAddress
        self.arch = arch
        self.path = path
    }
}
