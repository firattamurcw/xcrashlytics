//
//  FirebaseDTO.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation

/// Wire-level types that mirror `firebasecrashlytics.googleapis.com/v1alpha`
/// (the same schema documented at firebase.google.com/docs/reference/crashlytics/rest).
public enum FirebaseDTO {
    // MARK: - topIssues report

    /// Response from `reports/topIssues`.
    public struct TopIssuesResponse: Codable, Sendable, Equatable {
        public let groups: [IssueGroup]?
        public let nextPageToken: String?
    }

    /// One row in the topIssues report — issue + its metrics.
    public struct IssueGroup: Codable, Sendable, Equatable {
        public let issue: IssueDTO
        public let metrics: [IssueMetrics]?
    }

    /// Counts associated with an issue at the top-N level.
    public struct IssueMetrics: Codable, Sendable, Equatable {
        public let eventsCount: String?
        public let impactedUsersCount: String?
    }

    // MARK: - Issue

    /// A single Crashlytics issue. Matches the documented `Issue` schema.
    public struct IssueDTO: Codable, Sendable, Equatable {
        public let id: String
        public let title: String?
        public let subtitle: String?
        public let errorType: String?
        public let state: String?
        public let sampleEvent: String?
        public let uri: String?
        public let firstSeenVersion: String?
        public let lastSeenVersion: String?
        public let signals: [Signal]?
        public let name: String?

        public struct Signal: Codable, Sendable, Equatable {
            public let signal: String?
            public let description: String?
        }
    }

    // MARK: - Event

    /// Response from `events` (events.list).
    public struct EventsResponse: Codable, Sendable, Equatable {
        public let events: [EventDTO]?
        public let nextPageToken: String?
    }

    /// Wire shape of a single event from `events.list`. Frames carry symbol +
    /// file + line + library + owner.
    public struct EventDTO: Codable, Sendable, Equatable {
        public let name: String?
        public let platform: String?
        public let eventId: String?
        public let eventTime: String?
        public let bundleOrPackage: String?
        public let issue: EventIssueDTO?
        public let issueTitle: String?
        public let issueSubtitle: String?
        public let processState: String?
        public let version: VersionDTO?
        public let device: DeviceDTO?
        public let operatingSystem: OperatingSystemDTO?
        public let memory: ResourceDTO?
        public let storage: ResourceDTO?
        public let user: UserDTO?
        public let blameFrame: FrameDTO?
        public let exceptions: [ExceptionDTO]?
        public let threads: [ThreadDTO]?
        public let rawJSON: String?
    }

    public struct EventIssueDTO: Codable, Sendable, Equatable {
        public let id: String?
        public let name: String?
        public let title: String?
        public let subtitle: String?
        public let rawValue: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case title
            case subtitle
            case rawValue
        }

        public init(from decoder: Decoder) throws {
            let single = try decoder.singleValueContainer()
            if let value = try? single.decode(String.self) {
                self.id = value.split(separator: "/").last.map(String.init) ?? value
                self.name = value
                self.title = nil
                self.subtitle = nil
                self.rawValue = value
                return
            }

            let object = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try object.decodeIfPresent(String.self, forKey: .id)
            self.name = try object.decodeIfPresent(String.self, forKey: .name)
            self.title = try object.decodeIfPresent(String.self, forKey: .title)
            self.subtitle = try object.decodeIfPresent(String.self, forKey: .subtitle)
            self.rawValue = nil
        }

        public func encode(to encoder: Encoder) throws {
            var object = encoder.container(keyedBy: CodingKeys.self)
            try object.encodeIfPresent(id, forKey: .id)
            try object.encodeIfPresent(name, forKey: .name)
            try object.encodeIfPresent(title, forKey: .title)
            try object.encodeIfPresent(subtitle, forKey: .subtitle)
            try object.encodeIfPresent(rawValue, forKey: .rawValue)
        }
    }

    public struct VersionDTO: Codable, Sendable, Equatable {
        public let displayVersion: String?
        public let buildVersion: String?
    }

    public struct DeviceDTO: Codable, Sendable, Equatable {
        public let model: String?
        public let orientation: String?
    }

    public struct OperatingSystemDTO: Codable, Sendable, Equatable {
        public let displayVersion: String?
        public let jailbroken: Bool?
        public let orientation: String?
    }

    public struct ResourceDTO: Codable, Sendable, Equatable {
        public let free: FlexibleInt?
        public let used: FlexibleInt?
    }

    public struct UserDTO: Codable, Sendable, Equatable {
        public let id: String?
    }

    public struct FlexibleInt: Codable, Sendable, Equatable {
        public let intValue: Int?

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(Int.self) {
                self.intValue = value
            } else if let value = try? container.decode(String.self) {
                self.intValue = Int(value)
            } else {
                self.intValue = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            if let intValue {
                try container.encode(intValue)
            } else {
                try container.encodeNil()
            }
        }
    }

    public struct ThreadDTO: Codable, Sendable, Equatable {
        public let name: String?
        public let title: String?
        public let crashed: Bool?
        public let frames: [FrameDTO]?
    }

    public struct ExceptionDTO: Codable, Sendable, Equatable {
        public let type: String?
        public let exceptionMessage: String?
        public let title: String?
        public let subtitle: String?
        public let blamed: Bool?
        public let frames: [FrameDTO]?
    }

    public struct FrameDTO: Codable, Sendable, Equatable {
        public let symbol: String?
        public let file: String?
        public let line: String?
        public let library: String?
        public let owner: String?
        public let blamed: Bool?
        public let offset: String?
    }
}

extension FirebaseDTO.EventsResponse {
    /// Decodes events and attaches each raw event object so callers can keep
    /// fields that are not yet promoted to typed properties.
    public static func decodePreservingRawEvents(from data: Data) throws -> Self {
        let decoded = try JSONDecoder().decode(Self.self, from: data)
        guard
            let events = decoded.events,
            let rawEvents = rawEventJSONs(from: data),
            events.count == rawEvents.count
        else {
            return decoded
        }
        return Self(
            events: zip(events, rawEvents).map { event, rawJSON in
                event.withRawJSON(rawJSON)
            },
            nextPageToken: decoded.nextPageToken
        )
    }

    private static func rawEventJSONs(from data: Data) -> [String]? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let events = object["events"] as? [Any]
        else {
            return nil
        }
        return events.compactMap { event in
            guard JSONSerialization.isValidJSONObject(event) else { return nil }
            guard let data = try? JSONSerialization.data(withJSONObject: event, options: [.sortedKeys]) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }
    }
}

extension FirebaseDTO.EventDTO {
    fileprivate func withRawJSON(_ rawJSON: String) -> Self {
        Self(
            name: name,
            platform: platform,
            eventId: eventId,
            eventTime: eventTime,
            bundleOrPackage: bundleOrPackage,
            issue: issue,
            issueTitle: issueTitle,
            issueSubtitle: issueSubtitle,
            processState: processState,
            version: version,
            device: device,
            operatingSystem: operatingSystem,
            memory: memory,
            storage: storage,
            user: user,
            blameFrame: blameFrame,
            exceptions: exceptions,
            threads: threads,
            rawJSON: rawJSON
        )
    }
}

extension FirebaseDTO.IssueDTO {
    /// Maps a Firebase issue to xcrashlytics' canonical `CrashRecord`.
    public func toCrashRecord() -> CrashRecord {
        let primarySignal = signals?.first?.signal
        return CrashRecord(
            id: id,
            source: .firebase,
            bundleId: nil,
            bundleVersion: lastSeenVersion ?? firstSeenVersion,
            osVersion: nil,
            deviceModel: nil,
            crashedThreadIndex: 0,
            exception: ExceptionInfo(
                exceptionType: errorType ?? title ?? "UNKNOWN",
                signal: primarySignal,
                subtype: subtitle,
                description: title
            ),
            frames: [],
            binaryImages: [],
            timestamp: nil,
            rawPath: nil,
            firstSeenVersion: firstSeenVersion,
            lastSeenVersion: lastSeenVersion
        )
    }
}

extension FirebaseDTO.EventDTO {
    /// Maps event frames into our `Frame` model. Drops the wire-only `owner` /
    /// `blamed` / `offset` flags.
    public func toFrames() -> [Frame] {
        guard let chosen = (
            threads?.first(where: { $0.crashed == true })?.frames
                ?? threads?.first?.frames
                ?? exceptions?.first?.frames
                ?? blameFrame.map { [$0] }
        ) else {
            return []
        }
        return chosen.enumerated().map { idx, f in
            Frame(
                index: idx,
                binaryName: f.library ?? "?",
                symbol: f.symbol,
                file: f.file,
                line: f.line.flatMap(Int.init),
                column: nil,
                address: nil,
                imageUUID: nil,
                isSymbolicated: f.symbol != nil
            )
        }
    }
}
