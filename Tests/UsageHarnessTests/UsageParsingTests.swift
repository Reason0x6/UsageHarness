import XCTest
@testable import UsageHarness

final class UsageParsingTests: XCTestCase {
    func testCodexRateLimits() {
        let input = #"{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":12000},"model_context_window":200000},"rate_limits":{"primary":{"used_percent":73,"window_minutes":300,"resets_at":2000000000},"secondary":{"used_percent":7,"window_minutes":10080}}}}"#
        let result = CodexUsageParser.parse(input)

        XCTAssertEqual(result.metrics.count, 2)
        XCTAssertEqual(result.metrics[0].fractionUsed, 0.73)
        XCTAssertEqual(result.metrics[0].title, "5-hour window")
        XCTAssertEqual(result.metrics[1].title, "7-day window")
    }

    func testCodexFallsBackToContext() {
        let input = #"{"payload":{"info":{"total_token_usage":{"total_tokens":50000},"model_context_window":200000}}}"#
        let result = CodexUsageParser.parse(input)

        XCTAssertEqual(result.metrics.count, 1)
        XCTAssertEqual(result.metrics[0].fractionUsed, 0.25)
    }

    func testClaudeUsesLatestContextAndTotalsOutput() {
        let input = """
        {"message":{"usage":{"input_tokens":1000,"cache_read_input_tokens":2000,"output_tokens":500}}}
        {"message":{"usage":{"input_tokens":2000,"cache_read_input_tokens":3000,"cache_creation_input_tokens":1000,"output_tokens":1000}}}
        """
        let result = ClaudeUsageParser.parse(input)

        XCTAssertEqual(result.tokens, 7000)
        XCTAssertEqual(result.metrics[0].fractionUsed, 0.035)
        XCTAssertEqual(result.metrics[1].valueText, "1.5K tokens")
    }
}
