//
//  JSONRenderer.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation

/// Renders crash data as stable JSON for AI agents and scripts.
public struct JSONRenderer: Sendable {
    public init() {}

    public func renderDetail(_ event: CrashRecord, activity: IssueActivitySummary? = nil) throws -> String {
        guard let activity else { return try encode(event) }
        return try encode(DetailPayload(event: event, activity: activity))
    }

    /// The crash record's own fields at the top level plus an `activity`
    /// object — additive against the bare-detail schema.
    struct DetailPayload: Encodable {
        let event: CrashRecord
        let activity: IssueActivitySummary

        enum CodingKeys: String, CodingKey { case activity }

        func encode(to encoder: Encoder) throws {
            try event.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(activity, forKey: .activity)
        }
    }

    public func renderGroups(_ groups: [CrashGroup], limit: Int?) throws -> String {
        let limited = limit.map { Array(groups.prefix($0)) } ?? groups
        return try encode(limited.map(GroupPayload.init))
    }

    struct GroupPayload: Encodable {
        let symbol: String
        let module: String?
        let crossSource: Bool
        let totalEvents: Int
        let totalUsers: Int
        let firebase: [CrashRecord]
        let xcode: [XcodeCrash]

        init(_ group: CrashGroup) {
            symbol = group.symbol
            module = group.module
            crossSource = group.isCrossSource
            totalEvents = group.totalEvents
            totalUsers = group.totalUsers
            firebase = group.firebase
            xcode = group.xcode
        }
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        try PayloadEncoder.json(value)
    }
}
