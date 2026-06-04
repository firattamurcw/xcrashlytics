//
//  EventMetadataTests.swift
//  xcrashlyticsTests
//
//  Created by FIRAT TAMUR on 8.06.2026.
//

import Foundation
import Testing
@testable import XCrashlyticsCore

@Suite("Firebase event metadata")
struct EventMetadataTests {
    @Test("indexes raw domains and userInfo keys")
    func indexesRawMetadata() throws {
        let json = #"""
        {
          "eventId": "E1",
          "error": {
            "domain": "com.metrickit.diagnostics.cpu",
            "userInfo": {
              "reason": "cpu spike",
              "diagnosis": "main-thread hang",
              "top_frames": "BlurDetectionService.analyzeBlur"
            }
          }
        }
        """#
        let event = FirebaseDTO.EventDTO(
            name: nil,
            platform: nil,
            eventId: "E1",
            eventTime: nil,
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
            rawJSON: json
        )
        let metadata = FirebaseEventMetadata(event)

        #expect(metadata.matches("com.metrickit.diagnostics.cpu"))
        #expect(metadata.matchesDomain("com.metrickit.diagnostics"))
        #expect(metadata.matchesUserInfoFilter("reason=cpu spike"))
        #expect(metadata.matchesUserInfoFilter("top_frames"))
        #expect(!metadata.matchesUserInfoFilter("reason=oom"))
    }
}
