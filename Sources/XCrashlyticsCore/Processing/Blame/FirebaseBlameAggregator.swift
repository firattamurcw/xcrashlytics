//
//  FirebaseBlameAggregator.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 8.06.2026.
//

import Foundation

public struct BlameSummary: Encodable, Sendable {
    public var file: String?
    public var line: Int?
    public var symbol: String?
    public var binaryName: String?
    public var eventCount: Int
    public var users: Int
    public var exampleIssueId: String
    public var exampleEventId: String?
    public var topIssueIds: [String]

    fileprivate init(_ bucket: BlameBucket) {
        self.file = bucket.key.file
        self.line = bucket.key.line
        self.symbol = bucket.key.symbol
        self.binaryName = bucket.key.binaryName
        self.eventCount = bucket.eventCount
        self.users = bucket.userHashes.count
        self.exampleIssueId = bucket.exampleIssueId ?? "unknown"
        self.exampleEventId = bucket.exampleEventId
        self.topIssueIds = bucket.issueEventCounts
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key < $1.key
            }
            .prefix(10)
            .map(\.key)
    }
}

public struct FirebaseBlameAggregator {
    public var firebase: FirebaseCrashlyticsClient
    public var top: Int
    public var cutoff: Date?
    public var eventsPerIssue: Int
    public var concurrency: Int

    public init(
        firebase: FirebaseCrashlyticsClient,
        top: Int,
        cutoff: Date?,
        eventsPerIssue: Int,
        concurrency: Int = 6
    ) {
        self.firebase = firebase
        self.top = top
        self.cutoff = cutoff
        self.eventsPerIssue = eventsPerIssue
        self.concurrency = concurrency
    }

    public func aggregate(issues: [CrashRecord]) async throws -> [BlameSummary] {
        var buckets: [BlameKey: BlameBucket] = [:]
        let samples = try await IssueEventSampler(
            firebase: firebase, eventsPerIssue: eventsPerIssue, concurrency: concurrency
        ).sample(issues: issues)
        for sample in samples {
            add(events: sample.events, issue: sample.issue, to: &buckets)
        }
        return buckets.values
            .map(BlameSummary.init)
            .sorted {
                if $0.eventCount != $1.eventCount { return $0.eventCount > $1.eventCount }
                if $0.users != $1.users { return $0.users > $1.users }
                return "\($0.file ?? "")\($0.symbol ?? "")" < "\($1.file ?? "")\($1.symbol ?? "")"
            }
            .prefix(max(1, top))
            .map { $0 }
    }

    private func add(
        events: [FirebaseDTO.EventDTO],
        issue: CrashRecord,
        to buckets: inout [BlameKey: BlameBucket]
    ) {
        for event in events where EventDates.isIncluded(event: event, onOrAfter: cutoff) {
            guard let frame = FirebaseEventFrames.blamedFrame(from: event) else { continue }
            let key = BlameKey(frame: frame)
            var bucket = buckets[key] ?? BlameBucket(key: key)
            bucket.eventCount += 1
            if let userId = event.user?.id {
                bucket.userHashes.insert(Hashing.sha256Hex(userId))
            }
            let issueId = Self.canonicalIssueId(issue.id)
            bucket.issueEventCounts[issueId, default: 0] += 1
            bucket.exampleIssueId = bucket.exampleIssueId ?? issueId
            bucket.exampleEventId = bucket.exampleEventId
                ?? Self.canonicalEventId(event, issueId: issue.id)
            buckets[key] = bucket
        }
    }

    private static func canonicalIssueId(_ issueId: String) -> String {
        issueId.hasPrefix("FB-") ? issueId : "FB-\(issueId)"
    }

    private static func canonicalEventId(_ event: FirebaseDTO.EventDTO, issueId: String) -> String {
        let firebaseEventId = event.eventId ?? event.name?.split(separator: "/").last.map(String.init) ?? "unknown"
        return "\(canonicalIssueId(issueId))/events/\(firebaseEventId)"
    }

}

private struct BlameKey: Hashable {
    var file: String?
    var line: Int?
    var symbol: String?
    var binaryName: String?

    init(frame: FirebaseDTO.FrameDTO) {
        self.file = frame.file
        self.line = frame.line.flatMap(Int.init)
        self.symbol = frame.symbol
        self.binaryName = frame.library
    }
}

private struct BlameBucket {
    var key: BlameKey
    var eventCount: Int = 0
    var userHashes: Set<String> = []
    var issueEventCounts: [String: Int] = [:]
    var exampleIssueId: String?
    var exampleEventId: String?
}
