//
//  FirebaseAppDiscovery.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 8.06.2026.
//

import Foundation

public struct DiscoveredFirebaseApp: Sendable, Equatable {
    public var profileName: String
    public var appId: String
    public var platform: String
    public var sourcePath: String

    public init(profileName: String, appId: String, platform: String, sourcePath: String) {
        self.profileName = profileName
        self.appId = appId
        self.platform = platform
        self.sourcePath = sourcePath
    }
}

public struct FirebaseAppDiscovery: Sendable {
    private let fs: FileSystem

    public init(fs: FileSystem) {
        self.fs = fs
    }

    public func discover(from root: String) throws -> [DiscoveredFirebaseApp] {
        let plistApps = try fs.enumerate(at: root, matchingExtensions: ["plist"])
            .filter { ($0 as NSString).lastPathComponent.hasSuffix("GoogleService-Info.plist") }
            .compactMap { path -> DiscoveredFirebaseApp? in
                guard let appId = try appIdFromPlist(path: path) else { return nil }
                return DiscoveredFirebaseApp(
                    profileName: profileName(for: path, root: root),
                    appId: appId,
                    platform: "ios",
                    sourcePath: relativePath(path, root: root)
                )
            }
        let jsonApps = try fs.enumerate(at: root, matchingExtensions: ["json"])
            .filter { ($0 as NSString).lastPathComponent == "google-services.json" }
            .compactMap { path -> DiscoveredFirebaseApp? in
                guard let appId = try appIdFromGoogleServicesJSON(path: path) else { return nil }
                return DiscoveredFirebaseApp(
                    profileName: profileName(for: path, root: root),
                    appId: appId,
                    platform: "android",
                    sourcePath: relativePath(path, root: root)
                )
            }
        return uniqueProfileNames(for: plistApps + jsonApps)
            .sorted { $0.profileName.localizedCaseInsensitiveCompare($1.profileName) == .orderedAscending }
    }

    private func appIdFromPlist(path: String) throws -> String? {
        let data = try fs.read(at: path)
        guard
            let object = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any],
            let appId = object["GOOGLE_APP_ID"] as? String,
            FirebaseClient.projectNumber(fromAppId: appId) != nil
        else {
            return nil
        }
        return appId
    }

    private func appIdFromGoogleServicesJSON(path: String) throws -> String? {
        let data = try fs.read(at: path)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let clients = object["client"] as? [[String: Any]]
        else {
            return nil
        }
        for client in clients {
            guard
                let info = client["client_info"] as? [String: Any],
                let appId = info["mobilesdk_app_id"] as? String,
                FirebaseClient.projectNumber(fromAppId: appId) != nil
            else {
                continue
            }
            return appId
        }
        return nil
    }

    private func profileName(for path: String, root: String) -> String {
        let relative = relativePath(path, root: root) as NSString
        let parent = relative.deletingLastPathComponent
        let raw = parent.isEmpty || parent == "." ? relative.deletingPathExtension : (parent as NSString).lastPathComponent
        return raw
            .replacingOccurrences(of: "GoogleService-Info", with: "")
            .replacingOccurrences(of: "google-services", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_ ."))
            .lowercased()
    }

    private func relativePath(_ path: String, root: String) -> String {
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard path.hasPrefix(prefix) else { return path }
        return String(path.dropFirst(prefix.count))
    }

    private func uniqueProfileNames(for apps: [DiscoveredFirebaseApp]) -> [DiscoveredFirebaseApp] {
        var counts: [String: Int] = [:]
        return apps.map { app in
            let count = counts[app.profileName, default: 0]
            counts[app.profileName] = count + 1
            guard count > 0 else { return app }
            var copy = app
            copy.profileName = "\(app.profileName)-\(count + 1)"
            return copy
        }
    }
}
