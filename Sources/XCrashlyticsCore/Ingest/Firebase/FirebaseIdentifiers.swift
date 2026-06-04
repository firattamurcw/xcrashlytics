//
//  FirebaseIdentifiers.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 8.06.2026.
//

public enum FirebaseIdentifiers {
    public static func issueId(from canonical: String) -> String {
        canonical.hasPrefix("FB-") ? String(canonical.dropFirst(3)) : canonical
    }

    public static func canonicalIssueId(_ issueId: String) -> String {
        issueId.hasPrefix("FB-") ? issueId : "FB-\(issueId)"
    }

    public static func canonicalEventId(_ event: FirebaseDTO.EventDTO, issueId: String) -> String {
        let firebaseEventId = event.eventId ?? event.name?.split(separator: "/").last.map(String.init) ?? "unknown"
        return "\(canonicalIssueId(issueId))/events/\(firebaseEventId)"
    }
}

public struct FirebaseEventRef: Sendable, Equatable {
    public var issueId: String
    public var eventId: String

    public init?(_ id: String) {
        guard id.hasPrefix("FB-"), let range = id.range(of: "/events/") else {
            return nil
        }
        self.issueId = String(id[id.index(id.startIndex, offsetBy: 3)..<range.lowerBound])
        self.eventId = String(id[range.upperBound...])
        guard !issueId.isEmpty, !eventId.isEmpty else { return nil }
    }
}
