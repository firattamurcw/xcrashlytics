//
//  XcodeCrashLoading.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 8.06.2026.
//

import XCrashlyticsCore

extension CommandContext {
    /// Loads local Xcode crashes from the given directories, surfacing loader
    /// warnings on the console.
    func loadXcodeCrashes(directories: [String]) -> [XcodeCrash] {
        let result = XcodeCrashLoader(fs: fileSystem).load(directories: directories)
        for warning in result.warnings {
            console.warn(warning)
        }
        return result.crashes
    }

    /// Organizer crash directories, scoped to the configured bundle id.
    /// Throws when no bundle id is resolvable from the config — Xcode crash
    /// commands refuse to run an unscoped scan.
    func xcodeCrashDirectories() throws -> [String] {
        let config = try ConfigFile(fileSystem: fileSystem).load()
        guard let bundleId = config.resolvedBundleId else {
            throw ConfigError.missingBundleId(profile: config.activeProfile)
        }
        return XcodeCrashLoader.standardDirectories(bundleId: bundleId)
    }
}
