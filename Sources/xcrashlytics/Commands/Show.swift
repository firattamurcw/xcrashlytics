//
//  Show.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import ArgumentParser
import Foundation
import XCrashlyticsCore

struct ShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show a single crash by id (XC-<uuid> or FB-<id>).",
        discussion: """
        Examples:
          xcrashlytics show FB-3aedb610eee1a41872d991ca62ce8566
          xcrashlytics show FB-3aedb610eee1a41872d991ca62ce8566/events/E1 --format json
          xcrashlytics show XC-AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE
        """
    )

    @Argument(help: "Crash id (XC-<uuid> or FB-<id>).")
    var id: String

    @Option(name: .long, help: "Output format: text (default) or json.")
    var format: OutputFormat = .text

    @Flag(name: .long, help: "Firebase only: only emit frames that look app-owned.")
    var appFramesOnly: Bool = false

    @Flag(name: .long, help: "Firebase only: drop redacted, deduplicated, and known system/SDK frames.")
    var noSystemFrames: Bool = false

    @Flag(name: .long, help: "Firebase only: prefer frames from Firebase's crashed thread.")
    var crashingThreadOnly: Bool = false

    func validate() throws {
        guard format != .ndjson else {
            throw ValidationError("--format ndjson is not supported by this command.")
        }
    }

    func run() async throws {
        try await reportingFailures(jsonOutput: format.isJSON) {
            try await runWithContext(.live())
        }
    }

    @discardableResult
    func runWithContext(_ ctx: CommandContext) async throws -> String {
        let (event, activity) = try await loadCrash(ctx: ctx)
        let output = try render(event, activity: activity)
        ctx.console.output(output)
        return output
    }

    private var frameOptions: FirebaseFrameFilterOptions {
        FirebaseFrameFilterOptions(
            appFramesOnly: appFramesOnly,
            noSystemFrames: noSystemFrames,
            crashingThreadOnly: crashingThreadOnly
        )
    }

    private func loadCrash(
        ctx: CommandContext
    ) async throws -> (event: CrashRecord, activity: IssueActivitySummary?) {
        if id.hasPrefix("XC-") {
            return (try xcodeCrash(ctx: ctx), nil)
        }
        let firebase = try ctx.firebaseClient()
        if let ref = FirebaseEventRef(id) {
            return (try await firebaseEvent(ref, firebase: firebase), nil)
        }
        if id.hasPrefix("FB-") {
            return try await firebaseIssue(firebase: firebase)
        }
        throw ValidationError("id must start with XC- or FB-; got '\(id)'.")
    }

    private func xcodeCrash(ctx: CommandContext) throws -> CrashRecord {
        let needle = String(id.dropFirst("XC-".count))
        let crashes = try ctx.loadXcodeCrashes(directories: ctx.xcodeCrashDirectories())
        guard let match = crashes.first(where: { $0.event.id == needle }) else {
            throw ValidationError("no crash found with id '\(id)'.")
        }
        return match.event
    }

    private func firebaseEvent(
        _ ref: FirebaseEventRef,
        firebase: FirebaseCrashlyticsClient
    ) async throws -> CrashRecord {
        let events = try await firebase.listEvents(issueID: ref.issueId, maxEvents: FirebaseEventSampling.limit)
        guard let dto = events.first(where: { event in
            let eventId = event.eventId ?? event.name?.split(separator: "/").last.map(String.init)
            return eventId == ref.eventId
        }) else {
            throw ValidationError("no Firebase event found with id '\(id)'.")
        }
        return FirebaseEventCrashMapper.crashRecord(from: dto, canonicalId: id, frameOptions: frameOptions)
    }

    private func firebaseIssue(
        firebase: FirebaseCrashlyticsClient
    ) async throws -> (event: CrashRecord, activity: IssueActivitySummary?) {
        let issueId = FirebaseIdentifiers.issueId(from: id)
        var event = try await firebase.getIssueDetail(id: issueId)
        let events = try await firebase.listEvents(issueID: issueId, maxEvents: FirebaseEventSampling.limit)
        if let latest = events.first {
            let frames = FirebaseEventFrames.frames(from: latest, options: frameOptions)
            event.frames = frames
        }
        return (event, events.isEmpty ? nil : IssueActivitySummary(events: events))
    }

    private func render(_ event: CrashRecord, activity: IssueActivitySummary?) throws -> String {
        if format == .json {
            return try JSONRenderer().renderDetail(event, activity: activity)
        } else {
            return PlainTextRenderer().renderDetail(event, activity: activity)
        }
    }
}
