//
//  ConfigFileTests.swift
//  xcrashlyticsTests
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation
import Testing
@testable import XCrashlyticsCore
import XCrashlyticsTestSupport

@Suite("ConfigFile")
struct ConfigFileTests {
    private var configPath: String {
        "\(FileManager.default.currentDirectoryPath)/.xcrashlytics.json"
    }

    @Test("returns defaults when file missing")
    func returnsDefaultsWhenMissing() throws {
        let fs = InMemoryFileSystem()
        let store = ConfigFile(fileSystem: fs)
        let cfg = try store.load()
        #expect(cfg.appId == nil)
        #expect(cfg.activeProfile == nil)
        #expect(cfg.profiles.isEmpty)
    }

    @Test("saves and loads round trip")
    func roundTrip() throws {
        let fs = InMemoryFileSystem()
        let store = ConfigFile(fileSystem: fs)
        var cfg = Config()
        cfg.appId = "1:123:ios:abc"
        cfg.profiles["staging"] = AppProfile(appId: "1:456:ios:def", sourcePath: "Staging/GoogleService-Info.plist")
        cfg.activeProfile = "staging"
        try store.save(cfg)
        let loaded = try store.load()
        #expect(loaded.appId == "1:123:ios:abc")
        #expect(loaded.activeProfile == "staging")
        #expect(loaded.resolvedAppId == "1:456:ios:def")
        #expect(loaded.profiles["staging"]?.sourcePath == "Staging/GoogleService-Info.plist")
    }

    @Test("resolved app id falls back to root app id when profile is missing")
    func resolvedAppIdFallback() {
        let cfg = Config(appId: "1:123:ios:abc", activeProfile: "missing")
        #expect(cfg.resolvedAppId == "1:123:ios:abc")
    }

    @Test("atomic save leaves no tmp file behind")
    func atomicLeavesNoTmp() throws {
        let fs = InMemoryFileSystem()
        let store = ConfigFile(fileSystem: fs)
        try store.save(Config())
        let tmpLeftovers = fs.snapshotPaths().filter { $0.contains(".tmp-") }
        #expect(tmpLeftovers.isEmpty)
    }

    @Test("corrupt file falls back to defaults")
    func corruptFallsBack() throws {
        let fs = InMemoryFileSystem()
        fs.seed(configPath, text: "not json")
        let store = ConfigFile(fileSystem: fs)
        let cfg = try store.load()
        #expect(cfg.appId == nil)
    }
}

@Suite("Firebase app discovery")
struct FirebaseAppDiscoveryTests {
    @Test("discovers iOS GoogleService plist app ids")
    func discoversIOSPlists() throws {
        let fs = InMemoryFileSystem()
        fs.seed("/repo/Debug/GoogleService-Info.plist", text: """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>GOOGLE_APP_ID</key>
          <string>1:1111111111:ios:debug</string>
        </dict>
        </plist>
        """)
        fs.seed("/repo/Staging/GoogleService-Info.plist", text: """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>GOOGLE_APP_ID</key>
          <string>1:2222222222:ios:staging</string>
        </dict>
        </plist>
        """)

        let apps = try FirebaseAppDiscovery(fs: fs).discover(from: "/repo")

        #expect(apps.map(\.profileName) == ["debug", "staging"])
        #expect(apps.map(\.appId) == ["1:1111111111:ios:debug", "1:2222222222:ios:staging"])
    }

    @Test("discovers Android google-services app ids")
    func discoversAndroidJSON() throws {
        let fs = InMemoryFileSystem()
        fs.seed("/repo/app/google-services.json", text: """
        {
          "client": [
            {
              "client_info": {
                "mobilesdk_app_id": "1:3333333333:android:release"
              }
            }
          ]
        }
        """)

        let apps = try FirebaseAppDiscovery(fs: fs).discover(from: "/repo")

        #expect(apps.map(\.profileName) == ["app"])
        #expect(apps.first?.platform == "android")
        #expect(apps.first?.appId == "1:3333333333:android:release")
    }
}
