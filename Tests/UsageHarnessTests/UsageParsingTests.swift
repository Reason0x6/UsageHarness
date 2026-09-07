import Foundation
import XCTest
@testable import UsageHarness

final class UsageParsingTests: XCTestCase {
    func testClaudeQuotaWindows() throws {
        let input = #"{"five_hour":{"utilization":73.5,"resets_at":"2026-09-07T12:00:00.000Z"},"seven_day":{"utilization":21,"resets_at":"2026-09-10T00:00:00Z"}}"#
        let result = try XCTUnwrap(ClaudeQuotaParser.parse(Data(input.utf8)))

        XCTAssertEqual(result.fiveHour?.utilization, 73.5)
        XCTAssertEqual(result.sevenDay?.utilization, 21)
        XCTAssertNotNil(result.fiveHour?.resetsAt)
    }

    func testClaudeCachedLimitShape() throws {
        let input = #"{"cachedUsageUtilization":{"limits":[{"kind":"session","percent":18,"resets_at":"2026-09-07T12:00:00Z"},{"kind":"weekly_all","percent":42,"resets_at":"2026-09-10T00:00:00Z"}]}}"#
        let result = try XCTUnwrap(ClaudeQuotaParser.parse(Data(input.utf8)))

        XCTAssertEqual(result.fiveHour?.utilization, 18)
        XCTAssertEqual(result.sevenDay?.utilization, 42)
    }

    func testClaudeDeduplicatesStreamingMessageRecords() {
        let input = """
        {"message":{"id":"msg-1","usage":{"input_tokens":1000,"cache_read_input_tokens":2000,"output_tokens":500}}}
        {"message":{"id":"msg-1","usage":{"input_tokens":1000,"cache_read_input_tokens":2000,"output_tokens":1000}}}
        {"message":{"id":"msg-2","usage":{"input_tokens":2000,"cache_read_input_tokens":3000,"cache_creation_input_tokens":1000,"output_tokens":1000}}}
        """
        let result = ClaudeUsageParser.parse(input)

        XCTAssertEqual(result.totalTokens, 11_000)
        XCTAssertEqual(result.currentContextTokens, 7_000)
    }

    func testClaudeCredentialParsing() {
        let input = #"{"claudeAiOauth":{"accessToken":"test-token","refreshToken":"not-used"}}"#
        XCTAssertEqual(ClaudeCredentialParser.accessToken(from: Data(input.utf8)), "test-token")
    }
}
