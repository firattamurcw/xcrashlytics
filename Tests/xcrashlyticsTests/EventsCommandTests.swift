//
//  EventsCommandTests.swift
//  xcrashlyticsTests
//
//  Created by FIRAT TAMUR on 5.06.2026.
//

import Foundation
import Testing
@testable import XCrashlyticsCore
import XCrashlyticsTestSupport
@testable import xcrashlytics

@Suite("xcrashlytics events")
struct EventsCommandTests {
    private let appId = "1:1234567890:ios:abcdef"

    @Test("renders compact text from live Firebase")
    func rendersText() async throws {
        let fs = try makeConfig()
        let http = makeEventsHTTP()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try EventsCommand.parse(["FB-I1"])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(http)

        )

        #expect(output.contains("FB-I1/events/E1"))
        #expect(output.contains("6.16.0 (937)"))
        #expect(output.contains("iPhone 17 Pro Max"))
        #expect(output.contains("iOS 26.4.1"))
        #expect(output.contains("644.05 MiB free RAM"))
        #expect(output.contains("BlurDetectionService.classifyWithML(_:)"))
    }

    @Test("renders compact JSON from live Firebase")
    func rendersJSON() async throws {
        let fs = try makeConfig()
        let http = makeEventsHTTP()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try EventsCommand.parse(["FB-I1", "--format", "json"])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(http)

        )

        #expect(output.contains(#""id" : "FB-I1/events/E1""#))
        #expect(output.contains(#""deviceModel" : "iPhone 17 Pro Max""#))
        #expect(output.contains(#""memoryFreeBytes" : 675335168"#))
        #expect(output.contains(#""symbol" : "BlurDetectionService.classifyWithML(_:)"#))
        #expect(!output.contains("rawJSON"))
    }

    @Test("ndjson emits one event object per line")
    func ndjsonOutput() async throws {
        let fs = try makeConfig()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try EventsCommand.parse([
            "--issues", "FB-I1,FB-I2",
            "--latest",
            "--format", "ndjson",
        ])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(makeBatchEventsHTTP())

        )

        let lines = output.split(separator: "\n")
        #expect(lines.count == 2)
        for line in lines {
            #expect(line.first == "{")
            #expect(line.contains("\"id\""))
        }
    }

    @Test("filters events by raw Firebase user id")
    func filtersEventsByUserId() async throws {
        let fs = try makeConfig()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try EventsCommand.parse([
            "FB-I1",
            "--user-id", "target-user",
            "--format", "json",
        ])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(makeUserEventsHTTP())

        )

        #expect(output.contains(#""id" : "FB-I1/events/E-target""#))
        #expect(!output.contains("E-other"))
        #expect(!output.contains("target-user"))
    }

    @Test("renders latest event frames only")
    func rendersLatestFramesOnly() async throws {
        let fs = try makeConfig()
        let http = makeEventsHTTP(expectedPageSize: "1")
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try EventsCommand.parse(["FB-I1", "--latest", "--frames-only", "--format", "json"])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(http)

        )

        #expect(output.contains(#""id" : "FB-I1/events/E1""#))
        #expect(output.contains(#""blamedFrame" : {"#))
        #expect(output.contains(#""file" : "BlurDetectionService.swift""#))
        #expect(output.contains(#""line" : 42"#))
        #expect(!output.contains("deviceModel"))
        #expect(!output.contains("memoryFreeBytes"))
    }

    @Test("filters frames to app frames only")
    func filtersAppFramesOnly() async throws {
        let fs = try makeConfig()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try EventsCommand.parse([
            "FB-I1",
            "--frames-only",
            "--app-frames-only",
            "--format", "json"
        ])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(makeNoisyEventsHTTP())

        )

        #expect(output.contains(#""symbol" : "BlurDetectionService.classifyWithML(_:)"#))
        #expect(output.contains(#""file" : "BlurDetectionService.swift""#))
        #expect(!output.contains("<redacted>"))
        #expect(!output.contains("<deduplicated_symbol>"))
        #expect(!output.contains("libsystem_kernel.dylib"))
    }

    @Test("frame filters imply frames-only text output")
    func frameFiltersImplyFramesOnlyTextOutput() async throws {
        let fs = try makeConfig()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try EventsCommand.parse(["FB-I1", "--crashing-thread-only", "--no-system-frames"])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(makeNoisyEventsHTTP())

        )

        #expect(output.contains("FB-I1/events/E1"))
        #expect(output.contains("  * 0 BlurDetectionService.swift:42 BlurDetectionService.classifyWithML(_:)"))
        #expect(!output.contains("unknown RAM"))
        #expect(!output.contains("<redacted>"))
    }

    @Test("fetches latest frames for comma separated issue batch")
    func fetchesBatchIssueFrames() async throws {
        let fs = try makeConfig()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try EventsCommand.parse([
            "--issues", "FB-I1,FB-I2",
            "--latest",
            "--frames-only",
            "--format", "json",
        ])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(makeBatchEventsHTTP())

        )

        #expect(output.contains(#""id" : "FB-I1/events/E1""#))
        #expect(output.contains(#""id" : "FB-I2/events/E2""#))
        #expect(output.contains(#""issueId" : "FB-I1""#))
        #expect(output.contains(#""issueId" : "FB-I2""#))
    }

    @Test("can request the crashing thread frames only")
    func filtersCrashingThreadOnly() async throws {
        let fs = try makeConfig()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try EventsCommand.parse([
            "FB-I1",
            "--frames-only",
            "--crashing-thread-only",
            "--format", "json"
        ])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(makeNoisyEventsHTTP())

        )

        #expect(output.contains("BlurDetectionService.classifyWithML"))
        #expect(!output.contains("BackgroundWorker.run"))
    }

    @Test("user-id filter scans past --limit and reports scannedEvents")
    func userIdOverFetch() async throws {
        let fs = try makeConfig()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try EventsCommand.parse(["FB-I1", "--limit", "5", "--user-id", "U1", "--format", "json"])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(makeOverFetchEventsHTTP())

        )

        #expect(output.contains("\"scannedEvents\" : 20"))
        #expect(output.contains("E-MATCH"))
        // E-1 (non-matching user) must be absent; use the exact JSON token to avoid
        // false negatives from substring matches against E-10, E-11, etc.
        #expect(!output.contains("\"E-1\""))
    }

    @Test("uses first thread frames when Firebase omits crashed flag")
    func rendersFramesWithoutCrashedThreadFlag() async throws {
        let fs = try makeConfig()
        let ctx = CommandContext(
            fileSystem: fs,
            processRunner: MockProcessRunner(),
            clock: FixedClock(),
            keychain: InMemoryKeychainStore()
        )
        let cmd = try EventsCommand.parse(["FB-I1", "--frames-only", "--format", "json"])

        let output = try await cmd.runWithContext(
            ctx.withFirebaseHTTP(makeEventsHTTPWithoutCrashedThreadFlag())

        )

        #expect(output.contains(#""symbol" : "BlurDetectionService.classifyWithML(_:)"#))
        #expect(output.contains(#""symbol" : "FIRCLSUserLoggingRecordError""#))
        #expect(output.contains(#""isBlamed" : true"#))
    }

    private func makeConfig() throws -> InMemoryFileSystem {
        let fs = InMemoryFileSystem()
        try ConfigFile(fileSystem: fs).save(Config(appId: appId))
        return fs
    }

    private func makeEventsHTTP(expectedPageSize: String = "10") -> MockHTTPClient {
        MockHTTPClient { request in
            #expect(request.url?.path.hasSuffix("/events") == true)
            #expect(request.url?.query?.contains("filter.issue.id=I1") == true)
            #expect(request.url?.query?.contains("page_size=\(expectedPageSize)") == true)
            let body = #"""
            {"events":[{
              "name":"projects/123/apps/app/events/E1",
              "eventId":"E1",
              "eventTime":"2026-06-05T12:09:45Z",
              "processState":"FOREGROUND",
              "version":{"displayVersion":"6.16.0","buildVersion":"937"},
              "device":{"model":"iPhone 17 Pro Max","orientation":"PORTRAIT"},
              "operatingSystem":{"displayVersion":"26.4.1","jailbroken":false,"orientation":"PORTRAIT"},
              "memory":{"free":"675335168","used":"1234567890"},
              "storage":{"free":"12345","used":"67890"},
              "user":{"id":"033EF509-4BDD-4596-8BA9-E988E3342614"},
              "threads":[{"crashed":true,"frames":[
                {"symbol":"BlurDetectionService.classifyWithML(_:)","library":"Core","file":"BlurDetectionService.swift","line":"42","blamed":true}
              ]}]
            }]}
            """#
            return MockHTTPClient.response(request.url!, status: 200, body: Data(body.utf8))
        }
    }

    private func makeEventsHTTPWithoutCrashedThreadFlag() -> MockHTTPClient {
        MockHTTPClient { request in
            #expect(request.url?.path.hasSuffix("/events") == true)
            let body = #"""
            {"events":[{
              "name":"projects/123/apps/app/events/E1",
              "eventId":"E1",
              "eventTime":"2026-06-05T12:09:45Z",
              "blameFrame":{
                "symbol":"BlurDetectionService.classifyWithML(_:)",
                "library":"Core",
                "file":"BlurDetectionService.swift",
                "line":"42",
                "blamed":true
              },
              "threads":[{"frames":[
                {"symbol":"FIRCLSUserLoggingRecordError","library":"Core","file":"FIRCLSUserLogging.m","line":"402"},
                {"symbol":"BlurDetectionService.classifyWithML(_:)","library":"Core","file":"BlurDetectionService.swift","line":"42"}
              ]}]
            }]}
            """#
            return MockHTTPClient.response(request.url!, status: 200, body: Data(body.utf8))
        }
    }

    private func makeUserEventsHTTP() -> MockHTTPClient {
        MockHTTPClient { request in
            #expect(request.url?.path.hasSuffix("/events") == true)
            let body = #"""
            {"events":[
              {
                "eventId":"E-target",
                "eventTime":"2026-06-08T10:00:00Z",
                "user":{"id":"target-user"},
                "threads":[{"crashed":true,"frames":[
                  {"symbol":"Target.run()","library":"Core","file":"Target.swift","line":"10","blamed":true}
                ]}]
              },
              {
                "eventId":"E-other",
                "eventTime":"2026-06-08T09:00:00Z",
                "user":{"id":"other-user"},
                "threads":[{"crashed":true,"frames":[
                  {"symbol":"Other.run()","library":"Core","file":"Other.swift","line":"20","blamed":true}
                ]}]
              }
            ]}
            """#
            return MockHTTPClient.response(request.url!, status: 200, body: Data(body.utf8))
        }
    }

    private func makeNoisyEventsHTTP() -> MockHTTPClient {
        MockHTTPClient { request in
            #expect(request.url?.path.hasSuffix("/events") == true)
            let body = #"""
            {"events":[{
              "name":"projects/123/apps/app/events/E1",
              "eventId":"E1",
              "eventTime":"2026-06-05T12:09:45Z",
              "blameFrame":{
                "symbol":"BlurDetectionService.classifyWithML(_:)",
                "library":"Core",
                "file":"BlurDetectionService.swift",
                "line":"42",
                "owner":"APPLICATION",
                "blamed":true
              },
              "threads":[
                {"name":"main","crashed":true,"frames":[
                  {"symbol":"<redacted>","library":"libsystem_kernel.dylib","owner":"SYSTEM"},
                  {"symbol":"<deduplicated_symbol>","library":"UIKitCore","owner":"SYSTEM"},
                  {
                    "symbol":"BlurDetectionService.classifyWithML(_:)",
                    "library":"Core",
                    "file":"BlurDetectionService.swift",
                    "line":"42",
                    "owner":"APPLICATION",
                    "blamed":true
                  }
                ]},
                {"name":"background","crashed":false,"frames":[
                  {"symbol":"BackgroundWorker.run()","library":"Core","file":"BackgroundWorker.swift","line":"12","owner":"APPLICATION"}
                ]}
              ]
            }]}
            """#
            return MockHTTPClient.response(request.url!, status: 200, body: Data(body.utf8))
        }
    }

    private func makeOverFetchEventsHTTP() -> MockHTTPClient {
        MockHTTPClient { request in
            #expect(request.url?.path.hasSuffix("/events") == true)
            #expect(request.url?.query?.contains("page_size=50") == true)
            // Build 20 events; only event 15 (index 14, 1-based = 15th) has user id "U1"
            let events: [String] = (1...20).map { i in
                let eventId = i == 15 ? "E-MATCH" : "E-\(i)"
                let userId = i == 15 ? "U1" : "U-other-\(i)"
                return """
                {
                  "eventId":"\(eventId)",
                  "eventTime":"2026-06-08T10:00:\(String(format: "%02d", i))Z",
                  "user":{"id":"\(userId)"},
                  "threads":[{"crashed":true,"frames":[
                    {"symbol":"Func\(i).run()","library":"Core","file":"File\(i).swift","line":"\(i)","blamed":true}
                  ]}]
                }
                """
            }
            let body = "{\"events\":[\(events.joined(separator: ","))]}"
            return MockHTTPClient.response(request.url!, status: 200, body: Data(body.utf8))
        }
    }

    private func makeBatchEventsHTTP() -> MockHTTPClient {
        MockHTTPClient { request in
            #expect(request.url?.path.hasSuffix("/events") == true)
            let issueId = request.url?.queryItem(named: "filter.issue.id")
            let eventId = issueId == "I2" ? "E2" : "E1"
            let symbol = issueId == "I2" ? "CameraPipeline.run()" : "BlurDetectionService.classifyWithML(_:)"
            let body = #"""
            {"events":[{
              "eventId":"\#(eventId)",
              "eventTime":"2026-06-05T12:09:45Z",
              "threads":[{"crashed":true,"frames":[
                {"symbol":"\#(symbol)","library":"Core","file":"Service.swift","line":"42","blamed":true}
              ]}]
            }]}
            """#
            return MockHTTPClient.response(request.url!, status: 200, body: Data(body.utf8))
        }
    }
}

private extension URL {
    func queryItem(named name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}
