//
//  MockHTTPClient.swift
//  xcrashlyticsTests
//
//  Created by FIRAT TAMUR on 4.06.2026.
//

import Foundation
import XCrashlyticsCore

/// Scripted `HTTPClient` for tests.
///
/// Tests provide a handler that maps `URLRequest` to a canned `(Data, HTTPURLResponse)`
/// or throws. A history of every dispatched request is kept for assertions.
public final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    public var handler: ((URLRequest) throws -> (Data, HTTPURLResponse))?
    public private(set) var requests: [URLRequest] = []

    public init(handler: ((URLRequest) throws -> (Data, HTTPURLResponse))? = nil) {
        self.handler = handler
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard let handler else {
            throw HTTPError.transport("no handler set on MockHTTPClient")
        }
        return try handler(request)
    }

    /// Convenience for building a JSON response from a `Data` body.
    public static func response(_ url: URL, status: Int, body: Data, headers: [String: String] = [:]) -> (Data, HTTPURLResponse) {
        let resp = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        return (body, resp)
    }
}
