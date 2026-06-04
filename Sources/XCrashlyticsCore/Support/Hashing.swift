//
//  Hashing.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 8.06.2026.
//

import CryptoKit
import Foundation

public enum Hashing {
    public static func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
