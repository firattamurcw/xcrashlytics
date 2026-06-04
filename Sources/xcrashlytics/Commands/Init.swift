//
//  Init.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import ArgumentParser
import Foundation
import XCrashlyticsCore

struct InitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Write .xcrashlytics.json in the current directory and verify the Firebase setup."
    )

    @Option(
        name: .long,
        help:
            "Firebase app id, any platform (GOOGLE_APP_ID from GoogleService-Info.plist / google-services.json)."
    )
    var appId: String

    @Option(
        name: .long,
        help: "Named environment profile to create and activate, for example staging or release."
    )
    var profile: String

    @Option(
        name: .long,
        help: "App bundle id — scopes Xcode Organizer crash scanning to ~/Library/Developer/Xcode/Products/<bundle-id>."
    )
    var bundleId: String?

    func run() async throws {
        try await reportingFailures(jsonOutput: false) {
            try await runWithContext(CommandContext.live())
        }
    }

    private enum Check {
        case ok
        case warn(String)
        case fail(String, hint: [String] = [])

        /// Only failures block writing the config.
        var blocks: Bool {
            if case .fail = self { return true }
            return false
        }

        var passed: Bool {
            if case .ok = self { return true }
            return false
        }

        var line: String? {
            switch self {
            case .ok:
                return nil
            case .warn(let message):
                return "[WARN] \(message)"
            case .fail(let message, let hint):
                return (["[FAIL] \(message)"] + hint.map { "          \($0)" }).joined(
                    separator: "\n")
            }
        }
    }

    @discardableResult
    func runWithContext(_ ctx: CommandContext) async throws -> String {
        let checks = try await verifySetup(ctx: ctx)
        let blocked = checks.contains { $0.blocks }
        let warned = checks.contains { if case .warn = $0 { return true } else { return false } }

        var lines = checks.compactMap(\.line)
        if blocked {
            lines.append("Some checks failed. Fix the above, then re-run `xcrashlytics init`.")
        } else {
            try writeConfig(ctx: ctx)
            lines.append(
                warned
                    ? "Setup OK — warnings above are advisory."
                    : "All checks passed.")
            lines.append(
                ".xcrashlytics.json created and active. It holds app ids only, no secrets"
                    + " — commit it so the team shares the setup.")
        }

        let output = lines.joined(separator: "\n") + "\n"
        ctx.console.output(output)
        if blocked { throw ExitCode(1) }
        return output
    }

    private func verifySetup(ctx: CommandContext) async throws -> [Check] {
        let cli = checkFirebaseCLI(ctx: ctx)
        let login = try await checkFirebaseLogin(ctx: ctx, isFirebaseCLIInstalled: cli.passed)
        return [cli, login, checkAppId(), checkBundleId(ctx: ctx)]
    }

    private func writeConfig(ctx: CommandContext) throws {
        let store = ConfigFile(fileSystem: ctx.fileSystem)
        var config = (try? store.load()) ?? Config()
        let name = profile.lowercased()
        config.profiles[name] = AppProfile(appId: appId, bundleId: bundleId)
        config.activeProfile = name
        try store.save(config)
    }

    private func checkFirebaseCLI(ctx: CommandContext) -> Check {
        let installed =
            (try? ctx.processRunner.run(
                executable: "/usr/bin/env",
                arguments: ["which", "firebase"],
                stdin: nil
            ))?.exitCode == 0
        guard installed else {
            return .fail(
                "firebase CLI is not installed. Install it, then run `firebase login`:",
                hint: [
                    "npm install -g firebase-tools   # or: brew install firebase-cli",
                    "firebase login",
                ])
        }
        return .ok
    }

    private func checkFirebaseLogin(ctx: CommandContext, isFirebaseCLIInstalled: Bool) async throws
        -> Check {
        let provider = FirebaseToolsTokenProvider(fs: ctx.fileSystem, httpClient: ctx.httpClient)
        guard provider.isFirebaseLoggedIn() else {
            return isFirebaseCLIInstalled
                ? .fail("firebase login not completed. Run: firebase login") : .ok
        }
        do {
            _ = try await provider.token()
            return .ok
        } catch let e as AccessTokenError {
            switch e {
            case .refreshTokenInvalid:
                return .fail("firebase refresh token is invalid. Run: firebase login --reauth")
            case .tokenExchangeFailed(let detail):
                return .warn("firebase token exchange failed: \(detail)")
            case .firebaseLoginRequired:
                return .fail("firebase login required. Run: firebase login")
            }
        }
    }

    private func checkAppId() -> Check {
        guard FirebaseClient.projectNumber(fromAppId: appId) != nil else {
            return .fail(
                "appId=\(appId) has wrong format. Expected '1:<number>:<platform>:<hash>'.")
        }
        return .ok
    }

    /// Advisory only — a missing bundle id never blocks the config write, but
    /// Xcode crash commands will refuse to run until one is set.
    private func checkBundleId(ctx: CommandContext) -> Check {
        guard let bundleId else {
            return .warn("no bundle id — Xcode crash commands need one. Re-run with --bundle-id <BUNDLE_ID>.")
        }
        let crashes = XcodeCrashLoader.standardDirectories(bundleId: bundleId).flatMap {
            (try? ctx.fileSystem.enumerate(at: $0, matchingExtensions: ["crash"])) ?? []
        }
        guard !crashes.isEmpty else {
            return .warn("no Organizer crashes for \(bundleId) yet — open Xcode Organizer once to download.")
        }
        return .ok
    }
}
