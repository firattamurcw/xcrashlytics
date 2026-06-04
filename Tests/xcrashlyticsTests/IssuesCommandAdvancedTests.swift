import Foundation
import Testing
@testable import XCrashlyticsCore
import XCrashlyticsTestSupport
@testable import xcrashlytics

extension IssuesCommandTests {
    @Test("renders NDJSON with one issue per line")
    func rendersNDJSON() async throws {
        let fs = try makeMultiIssuesHTTPConfig()
        let http = makeMultiIssuesHTTP()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try IssuesCommand.parse(["blur", "--format", "ndjson", "--limit", "200"])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(http)

        )

        let lines = output.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.contains(#""id":"FB-I"#) || $0.contains(#""id" : "FB-I"#) })
        #expect(!output.contains(#""issues""#))
    }

    @Test("uses the active profile app id for Firebase requests")
    func usesActiveProfileAppId() async throws {
        let fs = InMemoryFileSystem()
        try ConfigFile(fileSystem: fs).save(Config(
            appId: "1:1111111111:ios:debug",
            activeProfile: "staging",
            profiles: [
                "staging": AppProfile(appId: "1:2222222222:ios:staging")
            ]
        ))
        var requestedPath: String?
        let http = MockHTTPClient { request in
            requestedPath = request.url?.path
            return try makeIssuesHTTP().handler!(request)
        }
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try IssuesCommand.parse(["--format", "json"])

        _ = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(http)

        )

        #expect(requestedPath?.contains("/projects/2222222222/apps/1:2222222222:ios:staging/") == true)
    }

    @Test("query searches latest event metadata when issue fields do not match")
    func querySearchesEventMetadata() async throws {
        let fs = try makeConfig()
        let http = makeMetricKitHTTP()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try IssuesCommand.parse([
            "com.metrickit.diagnostics.cpu",
            "--format", "json",
        ])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(http)

        )

        #expect(output.contains(#""id" : "FB-MX""#))
        #expect(output.contains(#""eventMetadataSamples" : 1"#))
    }

    @Test("filters issues by event domain and userInfo key")
    func filtersByEventDomainAndUserInfo() async throws {
        let fs = try makeConfig()
        let http = makeMetricKitHTTP()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try IssuesCommand.parse([
            "--domain", "com.metrickit.diagnostics.cpu",
            "--user-info-key", "reason=cpu spike",
            "--format", "json",
        ])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(http)

        )

        #expect(output.contains(#""id" : "FB-MX""#))
        #expect(!output.contains(#""id" : "FB-OTHER""#))
    }

    @Test("filters issues by raw Firebase user id across sampled events")
    func filtersIssuesByUserId() async throws {
        let fs = try makeConfig()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try IssuesCommand.parse([
            "--user-id", "target-user",
            "--events-per-issue", "2",
            "--format", "json",
        ])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(makeUserIssuesHTTP())

        )

        #expect(output.contains(#""id" : "FB-I1""#))
        #expect(!output.contains(#""id" : "FB-I2""#))
        #expect(!output.contains("target-user"))
    }

    @Test("empty Firebase results with Xcode crashes include a dSYM hint")
    func emptyResultsIncludeDSYMHints() async throws {
        let http = makeRankedIssuesHTTP(matchIndex: nil, total: 2)
        let fs = InMemoryFileSystem()
        try ConfigFile(fileSystem: fs).save(Config(appId: appId))
        let crashDir = "/crashes"
        fs.seed("\(crashDir)/A.crash", text: try loadFixture("sample.crash"))
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try IssuesCommand.parse(["missing", "--xcode", "--format", "json"])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(http),
            crashDirectories: [crashDir]
        )

        #expect(output.contains(#""symbolicationHint" : "1 app dSYM UUID(s) may be needed for 1 Xcode crash(es).""#))
    }

    @Test("since all disables time filtering while since-version still applies")
    func sinceAllAndSinceVersionAreAndFilters() async throws {
        let fs = try makeConfig()
        let http = makeVersionedIssuesHTTP()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try IssuesCommand.parse([
            "--since", "all",
            "--since-version", "6.17.0",
            "--format", "json",
        ])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(http)

        )

        #expect(output.contains(#""id" : "FB-NEW""#))
        #expect(!output.contains(#""id" : "FB-OLD""#))
    }

    @Test("by-day adds per-issue event trend counts")
    func byDayAddsTrendCounts() async throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-06-08T12:00:00Z"))
        let fs = try makeConfig()
        let http = makeTrendHTTP()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(now),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try IssuesCommand.parse([
            "--since", "7d",
            "--by-day",
            "--format", "json",
        ])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(http)

        )

        #expect(output.contains(#""dailyEvents" : ["#))
        #expect(output.contains(#""day" : "2026-06-07""#))
        #expect(output.contains(#""eventsCount" : 2"#))
        #expect(output.contains(#""day" : "2026-06-08""#))
        #expect(output.contains(#""eventsCount" : 1"#))
        #expect(output.contains(#""dailyEventsTruncated" : false"#))
    }

    @Test("bare listing samples each issue's latest event for lastSeenAt")
    func bareListingAddsLastSeen() async throws {
        let fs = try makeMultiIssuesHTTPConfig()
        let http = makeMultiIssuesWithEventsHTTP()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try IssuesCommand.parse(["--format", "json"])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(http)

        )

        #expect(output.contains(#""lastSeenAt" : "2026-06-07T20:00:00Z""#))
        #expect(output.contains(#""lastSeenAt" : "2026-06-01T20:00:00Z""#))
    }

    @Test("by-day flags truncated trends when sample covers fewer events than total")
    func byDayFlagsTruncatedTrend() async throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-06-08T12:00:00Z"))
        let fs = try makeConfig()
        let http = makeTruncatedTrendHTTP()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(now),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try IssuesCommand.parse([
            "--by-day",
            "--format", "json",
        ])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(http)

        )

        #expect(output.contains(#""dailyEventsSampledCount" : 3"#))
        #expect(output.contains(#""dailyEventsTruncated" : true"#))
    }

    @Test("by-day text marks oldest sampled day partial for truncated trends")
    func byDayTextMarksTruncatedTrend() async throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-06-08T12:00:00Z"))
        let fs = try makeConfig()
        let http = makeTruncatedTrendHTTP()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(now),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try IssuesCommand.parse(["--by-day"])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(http)

        )

        #expect(output.contains("2026-06-07:≥2"))
        #expect(output.contains("2026-06-08:1"))
        #expect(output.contains("(sampled newest 3 of 737 events)"))
    }
}
