//
//  FirebaseEventCrashMapperTests.swift
//  xcrashlyticsTests
//
//  Created by FIRAT TAMUR on 10.06.2026.
//

import Foundation
import Testing
@testable import XCrashlyticsCore

@Suite("FirebaseEventCrashMapper")
struct FirebaseEventCrashMapperTests {
    private func makeEvent(eventTime: String?) -> FirebaseDTO.EventDTO {
        FirebaseDTO.EventDTO(
            name: nil,
            platform: nil,
            eventId: "E1",
            eventTime: eventTime,
            bundleOrPackage: nil,
            issue: nil,
            issueTitle: nil,
            issueSubtitle: nil,
            processState: nil,
            version: nil,
            device: nil,
            operatingSystem: nil,
            memory: nil,
            storage: nil,
            user: nil,
            blameFrame: nil,
            exceptions: nil,
            threads: nil,
            rawJSON: nil
        )
    }

    @Test("maps fractional-second eventTime to non-nil timestamp")
    func fractionalSecondsTimestamp() {
        let event = makeEvent(eventTime: "2026-06-10T12:00:00.500Z")
        let record = FirebaseEventCrashMapper.crashRecord(from: event, canonicalId: "FB-1")
        #expect(record.timestamp != nil)
    }

    @Test("maps whole-second eventTime to non-nil timestamp")
    func wholeSecondTimestamp() {
        let event = makeEvent(eventTime: "2026-06-10T12:00:00Z")
        let record = FirebaseEventCrashMapper.crashRecord(from: event, canonicalId: "FB-2")
        #expect(record.timestamp != nil)
    }

    @Test("nil eventTime yields nil timestamp")
    func nilTimestamp() {
        let event = makeEvent(eventTime: nil)
        let record = FirebaseEventCrashMapper.crashRecord(from: event, canonicalId: "FB-3")
        #expect(record.timestamp == nil)
    }

    @Test("Firebase frames carry no address — the API does not report one")
    func framesHaveNoAddress() throws {
        let json = #"""
        {
          "eventId": "E1",
          "threads": [
            {
              "crashed": true,
              "frames": [{ "symbol": "doWork()", "file": "Work.swift", "line": "12", "library": "MyApp" }]
            }
          ]
        }
        """#
        let event = try JSONDecoder().decode(FirebaseDTO.EventDTO.self, from: Data(json.utf8))
        let frames = event.toFrames()
        #expect(frames.count == 1)
        #expect(frames[0].address == nil)
    }
}
