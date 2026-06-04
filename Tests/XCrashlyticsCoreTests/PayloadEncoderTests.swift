import Foundation
import Testing
@testable import XCrashlyticsCore

@Suite("payload encoder")
struct PayloadEncoderTests {
    struct Sample: Encodable {
        var b = "two"
        var a = "one"
        var when = Date(timeIntervalSince1970: 0)
        var url = "https://example.com/x"
        var note = "line1\nline2"
    }

    @Test("json is pretty, key-sorted, iso8601 dates, unescaped slashes, trailing newline")
    func json() throws {
        let out = try PayloadEncoder.json(Sample())
        #expect(out.contains("\"a\" : \"one\""))
        #expect(out.range(of: "\"a\"")!.lowerBound < out.range(of: "\"b\"")!.lowerBound)
        #expect(out.contains("1970-01-01T00:00:00Z"))
        #expect(out.contains("https://example.com/x"))
        #expect(out.hasSuffix("\n"))
    }

    @Test("ndjson line is compact with no trailing newline")
    func ndjsonLine() throws {
        let out = try PayloadEncoder.ndjsonLine(Sample())
        #expect(!out.contains("\n"))
        #expect(out.contains("\"a\":\"one\""))
    }
}
