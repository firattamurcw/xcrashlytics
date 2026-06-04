//
//  IssuesTrendRenderingTests.swift
//  xcrashlyticsTests
//
//  Created by FIRAT TAMUR on 11.06.2026.
//

import Foundation
import Testing
@testable import XCrashlyticsCore

@Suite("Issues trend rendering")
struct IssuesTrendRenderingTests {
    private func issue(_ id: String, eventsCount: Int?) -> CrashRecord {
        CrashRecord(
            id: id, source: .firebase,
            crashedThreadIndex: 0,
            exception: ExceptionInfo(exceptionType: "EXC_BAD_ACCESS"),
            frames: [],
            eventsCount: eventsCount,
            impactedUsersCount: 1
        )
    }

    @Test("truncated trend marks oldest day partial and labels sample coverage")
    func truncatedTrendLabelsSampling() {
        let trend = IssueTrend(
            days: [
                DailyEventCount(day: "2026-06-09", eventsCount: 2),
                DailyEventCount(day: "2026-06-10", eventsCount: 98),
            ],
            sampledEvents: 100,
            totalEvents: 737,
            truncated: true
        )
        let out = IssuesRenderer.text(
            issues: [issue("I1", eventsCount: 737)],
            xcodeCrashes: [],
            hint: nil,
            symbolicationHint: nil,
            trends: ["I1": trend]
        )
        #expect(out.contains("2026-06-09:≥2"))
        #expect(out.contains("2026-06-10:98"))
        #expect(out.contains("(sampled newest 100 of 737 events)"))
    }

    @Test("complete trend renders counts without sampling label")
    func completeTrendHasNoLabel() {
        let trend = IssueTrend(
            days: [
                DailyEventCount(day: "2026-06-09", eventsCount: 2),
                DailyEventCount(day: "2026-06-10", eventsCount: 1),
            ],
            sampledEvents: 3,
            totalEvents: 3,
            truncated: false
        )
        let out = IssuesRenderer.text(
            issues: [issue("I1", eventsCount: 3)],
            xcodeCrashes: [],
            hint: nil,
            symbolicationHint: nil,
            trends: ["I1": trend]
        )
        #expect(out.contains("2026-06-09:2,2026-06-10:1"))
        #expect(!out.contains("sampled"))
        #expect(!out.contains("≥"))
    }

    @Test("truncated trend with unknown total labels sample size only")
    func truncatedTrendUnknownTotal() {
        let trend = IssueTrend(
            days: [DailyEventCount(day: "2026-06-10", eventsCount: 100)],
            sampledEvents: 100,
            totalEvents: nil,
            truncated: true
        )
        let out = IssuesRenderer.text(
            issues: [issue("I1", eventsCount: nil)],
            xcodeCrashes: [],
            hint: nil,
            symbolicationHint: nil,
            trends: ["I1": trend]
        )
        #expect(out.contains("(sampled newest 100 events)"))
    }

    @Test("version column renders first→last range when versions differ")
    func versionRangeRendering() {
        let spanning = CrashRecord(
            id: "I1", source: .firebase, bundleVersion: "6.16.0",
            crashedThreadIndex: 0,
            exception: ExceptionInfo(exceptionType: "EXC_BAD_ACCESS"),
            frames: [], eventsCount: 10, impactedUsersCount: 1,
            firstSeenVersion: "6.2.0", lastSeenVersion: "6.16.0")
        let single = CrashRecord(
            id: "I2", source: .firebase, bundleVersion: "6.16.0",
            crashedThreadIndex: 0,
            exception: ExceptionInfo(exceptionType: "EXC_BAD_ACCESS"),
            frames: [], eventsCount: 10, impactedUsersCount: 1,
            firstSeenVersion: "6.16.0", lastSeenVersion: "6.16.0")
        let out = IssuesRenderer.text(
            issues: [spanning, single],
            xcodeCrashes: [],
            hint: nil,
            symbolicationHint: nil,
            trends: [:]
        )
        #expect(out.contains("FB-I1   EXC_BAD_ACCESS   v6.2.0→v6.16.0"))
        #expect(out.contains("FB-I2   EXC_BAD_ACCESS   v6.16.0"))
        #expect(!out.contains("v6.16.0→v6.16.0"))
    }

    @Test("rows show the last-seen day when a latest event was sampled")
    func lastSeenDayRendering() {
        let out = IssuesRenderer.text(
            issues: [issue("I1", eventsCount: 10)],
            xcodeCrashes: [],
            hint: nil,
            symbolicationHint: nil,
            trends: [:],
            lastSeenAt: ["I1": "2026-06-07T20:00:00Z"]
        )
        #expect(out.contains("last seen 2026-06-07"))
    }

    @Test("issue summary exposes lastSeenAt in JSON")
    func issueSummaryLastSeenAt() throws {
        let summary = IssueSummary(issue("I1", eventsCount: 10), lastSeenAt: "2026-06-07T20:00:00Z")
        let json = try PayloadEncoder.json(summary)
        #expect(json.contains(#""lastSeenAt" : "2026-06-07T20:00:00Z""#))
    }

    @Test("issue summary exposes first- and last-seen versions in JSON")
    func issueSummarySeenVersions() throws {
        let issue = CrashRecord(
            id: "I1", source: .firebase, bundleVersion: "6.16.0",
            crashedThreadIndex: 0,
            exception: ExceptionInfo(exceptionType: "EXC_BAD_ACCESS"),
            frames: [],
            firstSeenVersion: "6.2.0", lastSeenVersion: "6.16.0")
        let json = try PayloadEncoder.json(IssueSummary(issue))
        #expect(json.contains(#""firstSeenVersion" : "6.2.0""#))
        #expect(json.contains(#""lastSeenVersion" : "6.16.0""#))
        #expect(json.contains(#""appVersion" : "6.16.0""#))
    }

    @Test("issue summary exposes trend sampling fields in JSON")
    func issueSummaryTrendFields() throws {
        let trend = IssueTrend(
            days: [DailyEventCount(day: "2026-06-10", eventsCount: 98)],
            sampledEvents: 100,
            totalEvents: 737,
            truncated: true
        )
        let summary = IssueSummary(issue("I1", eventsCount: 737), trend: trend)
        let json = try PayloadEncoder.json(summary)
        #expect(json.contains(#""dailyEventsSampledCount" : 100"#))
        #expect(json.contains(#""dailyEventsTruncated" : true"#))
        #expect(json.contains(#""day" : "2026-06-10""#))
    }
}
