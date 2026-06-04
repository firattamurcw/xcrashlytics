//
//  IssueCandidatePairs.swift
//  xcrashlytics
//
//  Created by FIRAT TAMUR on 8.06.2026.
//

public struct CandidatePair: Encodable, Sendable {
    public var left: String
    public var right: String
    public var score: Double
    public var reasons: [String]

    public init(left: String, right: String, score: Double, reasons: [String]) {
        self.left = left
        self.right = right
        self.score = score
        self.reasons = reasons
    }
}

public struct RelatedIssueGroup: Encodable, Sendable {
    public var issueIds: [String]
    public var reason: String

    public init(issueIds: [String], reason: String) {
        self.issueIds = issueIds
        self.reason = reason
    }
}

public enum IssueCandidatePairs {
    public static func build(firebase: [CrashRecord], xcode: [XcodeCrash]) -> [CandidatePair] {
        let items = firebase.map { CandidateItem(id: "FB-\($0.id)", signature: CrashSignature.of($0)) }
            + xcode.map { CandidateItem(id: $0.localId, signature: CrashSignature.of($0.event)) }
        let grouped = Dictionary(grouping: items.compactMap { item -> CandidateItem? in
            guard item.signature != nil else { return nil }
            return item
        }, by: { $0.signature?.symbol ?? "" })
        return grouped.keys.sorted().flatMap { key -> [CandidatePair] in
            let ids = (grouped[key] ?? []).map(\.id).sorted()
            guard ids.count > 1 else { return [] }
            return ids.indices.flatMap { leftIndex in
                ids.indices.compactMap { rightIndex in
                    guard rightIndex > leftIndex else { return nil }
                    return CandidatePair(
                        left: ids[leftIndex],
                        right: ids[rightIndex],
                        score: 1.0,
                        reasons: ["same crash signature"]
                    )
                }
            }
        }
    }
}

public enum RelatedIssueGroups {
    public static func build(firebase: [CrashRecord], xcode: [XcodeCrash]) -> [RelatedIssueGroup] {
        let pairs = IssueCandidatePairs.build(firebase: firebase, xcode: xcode)
        var edges: [String: Set<String>] = [:]
        for pair in pairs {
            edges[pair.left, default: []].insert(pair.right)
            edges[pair.right, default: []].insert(pair.left)
        }

        var visited: Set<String> = []
        return edges.keys.sorted().compactMap { start in
            guard !visited.contains(start) else { return nil }
            var stack = [start]
            var component: [String] = []
            visited.insert(start)
            while let id = stack.popLast() {
                component.append(id)
                for next in (edges[id] ?? []).sorted() where !visited.contains(next) {
                    visited.insert(next)
                    stack.append(next)
                }
            }
            let ids = component.sorted()
            guard ids.count > 1 else { return nil }
            return RelatedIssueGroup(issueIds: ids, reason: "same crash signature")
        }
    }
}

private struct CandidateItem {
    var id: String
    var signature: CrashSignature.Signature?
}
