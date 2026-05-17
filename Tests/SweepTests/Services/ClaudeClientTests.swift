import XCTest
@testable import Sweep

// MARK: - MockURLSession

final class MockURLSession: URLSessionProtocol, @unchecked Sendable {

    struct Response {
        let data: Data
        let statusCode: Int
    }

    /// Responses dequeued in order. Once the queue is empty the last enqueued
    /// response is returned for every subsequent call, so tests that enqueue
    /// a single response don't need to worry about call counts.
    var responseQueue: [Response] = []
    private var lastResponse: Response = Response(data: Data(), statusCode: 200)
    private(set) var requestsMade: [URLRequest] = []
    var errorToThrow: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestsMade.append(request)

        if let error = errorToThrow {
            throw error
        }

        if !responseQueue.isEmpty {
            lastResponse = responseQueue.removeFirst()
        }
        let response = lastResponse
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (response.data, httpResponse)
    }
}

// MARK: - Test fixtures

private enum Fixtures {
    static let testURL = URL(fileURLWithPath: "/Users/test/Downloads/invoice_may.pdf")
    static let testURL2 = URL(fileURLWithPath: "/Users/test/Downloads/screenshot_2026.png")
    static let testURL3 = URL(fileURLWithPath: "/Users/test/Downloads/random_archive.zip")

    static let fileItem1 = FileItem(
        url: testURL,
        size: 204_800,
        createdAt: Date(timeIntervalSinceNow: -14 * 86400),
        modifiedAt: Date(timeIntervalSinceNow: -14 * 86400),
        mimeType: "application/pdf"
    )

    static let fileItem2 = FileItem(
        url: testURL2,
        size: 1_048_576,
        createdAt: Date(timeIntervalSinceNow: -7 * 86400),
        modifiedAt: Date(timeIntervalSinceNow: -7 * 86400),
        mimeType: "image/png"
    )

    static let fileItem3 = FileItem(
        url: testURL3,
        size: 512_000,
        createdAt: Date(timeIntervalSinceNow: -30 * 86400),
        modifiedAt: Date(timeIntervalSinceNow: -30 * 86400),
        mimeType: "application/zip"
    )

    static let context = ContextProfile.seed

    /// Build a minimal valid Anthropic API response JSON with the given items.
    static func makeAPIResponse(items: [[String: Any]]) throws -> Data {
        let toolInput: [String: Any] = ["items": items]
        let contentBlock: [String: Any] = [
            "type": "tool_use",
            "id": "toolu_01",
            "name": "propose_actions",
            "input": toolInput
        ]
        let response: [String: Any] = [
            "id": "msg_01",
            "type": "message",
            "role": "assistant",
            "content": [contentBlock],
            "model": "claude-sonnet-4-5",
            "stop_reason": "tool_use",
            "usage": ["input_tokens": 100, "output_tokens": 50]
        ]
        return try JSONSerialization.data(withJSONObject: response)
    }

    /// A standard high-confidence move item for fileItem1.
    static var moveItem: [String: Any] {
        [
            "fileUrl": testURL.path,
            "action": ["type": "move", "destination": "/Users/test/Documents/Finance/Invoices"],
            "confidence": "high",
            "reason": "Invoice PDF matched the invoices rule.",
            "appliedRuleIds": ["invoices-pdf"]
        ]
    }

    /// A medium-confidence reviewLater item for fileItem2.
    static var reviewItem: [String: Any] {
        [
            "fileUrl": testURL2.path,
            "action": ["type": "reviewLater"],
            "confidence": "medium",
            "reason": "Screenshot that may be important.",
            "appliedRuleIds": []
        ]
    }

    /// A low-confidence item for fileItem3 (should be filtered).
    static var lowConfidenceItem: [String: Any] {
        [
            "fileUrl": testURL3.path,
            "action": ["type": "keep"],
            "confidence": "low",
            "reason": "Unknown file type.",
            "appliedRuleIds": []
        ]
    }
}

// MARK: - ClaudeClientTests

final class ClaudeClientTests: XCTestCase {

    private var mockSession: MockURLSession!
    private var mockKeychain: MockKeychainStore!
    private var client: ClaudeClient!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        mockKeychain = MockKeychainStore()
        mockKeychain.save(key: "anthropic_api_key", value: "test-api-key-12345")
        // Inject a no-op sleep so retry tests don't take seconds to run
        client = ClaudeClient(keychainStore: mockKeychain, urlSession: mockSession, sleepNanoseconds: { _ in })
    }

    override func tearDown() {
        mockSession = nil
        mockKeychain = nil
        client = nil
        super.tearDown()
    }

    // MARK: - Test 1: Valid response parses to correct PlannedItems

    func testValidToolUseResponseParsesToPlannedItems() async throws {
        let apiResponse = try Fixtures.makeAPIResponse(items: [Fixtures.moveItem, Fixtures.reviewItem])
        mockSession.responseQueue = [MockURLSession.Response(data: apiResponse, statusCode: 200)]

        let results = try await client.propose(
            files: [Fixtures.fileItem1, Fixtures.fileItem2],
            context: Fixtures.context
        )

        XCTAssertEqual(results.count, 2, "Both high and medium confidence items should be returned")

        // Verify first item (move)
        let moveResult = try XCTUnwrap(results.first(where: { $0.file.url == Fixtures.testURL }))
        XCTAssertEqual(moveResult.confidence, .high)
        XCTAssertEqual(moveResult.appliedRuleIds, ["invoices-pdf"])
        if case .move(let dest, _) = moveResult.action {
            XCTAssertEqual(dest, URL(fileURLWithPath: "/Users/test/Documents/Finance/Invoices"))
        } else {
            XCTFail("Expected .move action, got \(moveResult.action)")
        }

        // Verify second item (reviewLater)
        let reviewResult = try XCTUnwrap(results.first(where: { $0.file.url == Fixtures.testURL2 }))
        XCTAssertEqual(reviewResult.confidence, .medium)
        if case .reviewLater = reviewResult.action {
            // Expected
        } else {
            XCTFail("Expected .reviewLater action, got \(reviewResult.action)")
        }
    }

    // MARK: - Test 2: Low-confidence items are filtered out

    func testLowConfidenceItemsAreFiltered() async throws {
        let apiResponse = try Fixtures.makeAPIResponse(items: [
            Fixtures.moveItem,
            Fixtures.lowConfidenceItem
        ])
        mockSession.responseQueue = [MockURLSession.Response(data: apiResponse, statusCode: 200)]

        let results = try await client.propose(
            files: [Fixtures.fileItem1, Fixtures.fileItem3],
            context: Fixtures.context
        )

        XCTAssertEqual(results.count, 1, "Low confidence item should be filtered out")
        XCTAssertEqual(results.first?.file.url, Fixtures.testURL)
        XCTAssertEqual(results.first?.confidence, .high)
    }

    // MARK: - Test 3: Files with no matching response item are skipped silently

    func testFilesWithNoMatchingResponseItemAreSkipped() async throws {
        // Only return a response for fileItem1, not fileItem2
        let apiResponse = try Fixtures.makeAPIResponse(items: [Fixtures.moveItem])
        mockSession.responseQueue = [MockURLSession.Response(data: apiResponse, statusCode: 200)]

        let results = try await client.propose(
            files: [Fixtures.fileItem1, Fixtures.fileItem2],
            context: Fixtures.context
        )

        XCTAssertEqual(results.count, 1, "Only the matched file should appear in results")
        XCTAssertEqual(results.first?.file.url, Fixtures.testURL)
    }

    // MARK: - Test 4: 429 triggers retry with exponential backoff

    func testRateLimitRetryLogic() async throws {
        // Enqueue two 429s then a success
        let apiResponse = try Fixtures.makeAPIResponse(items: [Fixtures.moveItem])
        mockSession.responseQueue = [
            MockURLSession.Response(data: Data("rate limited".utf8), statusCode: 429),
            MockURLSession.Response(data: Data("rate limited".utf8), statusCode: 429),
            MockURLSession.Response(data: apiResponse, statusCode: 200)
        ]

        // Replace client with one that has a very short sleep so tests don't take 6s
        // We observe the retry count via requestsMade
        let results = try await client.propose(
            files: [Fixtures.fileItem1],
            context: Fixtures.context
        )

        XCTAssertEqual(mockSession.requestsMade.count, 3, "Should have made 3 requests (2 retries + success)")
        XCTAssertEqual(results.count, 1)
    }

    func testRateLimitAfterMaxRetriesThrowsRateLimited() async throws {
        // Enqueue three consecutive 429s (exhausts all retries)
        mockSession.responseQueue = [
            MockURLSession.Response(data: Data("rate limited".utf8), statusCode: 429),
            MockURLSession.Response(data: Data("rate limited".utf8), statusCode: 429),
            MockURLSession.Response(data: Data("rate limited".utf8), statusCode: 429)
        ]

        do {
            _ = try await client.propose(files: [Fixtures.fileItem1], context: Fixtures.context)
            XCTFail("Expected ClaudeClientError.rateLimited to be thrown")
        } catch ClaudeClientError.rateLimited {
            // Expected
        } catch {
            XCTFail("Expected rateLimited, got: \(error)")
        }

        XCTAssertEqual(mockSession.requestsMade.count, 3, "Should have made exactly 3 attempts")
    }

    // MARK: - Test 5: Missing API key throws missingAPIKey

    func testMissingAPIKeyThrows() async throws {
        mockKeychain.delete(key: "anthropic_api_key")

        do {
            _ = try await client.propose(files: [Fixtures.fileItem1], context: Fixtures.context)
            XCTFail("Expected ClaudeClientError.missingAPIKey to be thrown")
        } catch ClaudeClientError.missingAPIKey {
            // Expected
        } catch {
            XCTFail("Expected missingAPIKey, got: \(error)")
        }

        XCTAssertEqual(mockSession.requestsMade.count, 0, "No HTTP request should be made when key is missing")
    }

    // MARK: - Test 6: Response missing tool_use block throws noToolUseBlock

    func testMissingToolUseBlockThrows() async throws {
        // Return a response with only a text block, no tool_use
        let response: [String: Any] = [
            "id": "msg_01",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": "I cannot help with that."]],
            "model": "claude-sonnet-4-5",
            "stop_reason": "end_turn",
            "usage": ["input_tokens": 10, "output_tokens": 5]
        ]
        let data = try JSONSerialization.data(withJSONObject: response)
        mockSession.responseQueue = [MockURLSession.Response(data: data, statusCode: 200)]

        do {
            _ = try await client.propose(files: [Fixtures.fileItem1], context: Fixtures.context)
            XCTFail("Expected ClaudeClientError.noToolUseBlock to be thrown")
        } catch ClaudeClientError.noToolUseBlock {
            // Expected
        } catch {
            XCTFail("Expected noToolUseBlock, got: \(error)")
        }
    }

    // MARK: - Test 7: Non-2xx non-429 status throws httpError

    func testHTTPErrorStatusThrows() async throws {
        let body = Data("{\"error\": \"internal server error\"}".utf8)
        mockSession.responseQueue = [MockURLSession.Response(data: body, statusCode: 500)]

        do {
            _ = try await client.propose(files: [Fixtures.fileItem1], context: Fixtures.context)
            XCTFail("Expected ClaudeClientError.httpError to be thrown")
        } catch ClaudeClientError.httpError(let statusCode, let responseBody) {
            XCTAssertEqual(statusCode, 500)
            XCTAssertTrue(responseBody.contains("internal server error"))
        } catch {
            XCTFail("Expected httpError, got: \(error)")
        }
    }

    // MARK: - Test 8: Chunking sends multiple requests for > 50 files

    func testChunkingForLargeFileSets() async throws {
        // Create 75 file items
        let files = (1...75).map { i -> FileItem in
            FileItem(
                url: URL(fileURLWithPath: "/Users/test/Downloads/file\(i).txt"),
                size: 1024,
                createdAt: Date(timeIntervalSinceNow: -Double(i) * 86400),
                modifiedAt: Date(timeIntervalSinceNow: -Double(i) * 86400),
                mimeType: "text/plain"
            )
        }

        // Return empty items for both chunks
        let emptyResponse = try Fixtures.makeAPIResponse(items: [])
        mockSession.responseQueue = [
            MockURLSession.Response(data: emptyResponse, statusCode: 200),
            MockURLSession.Response(data: emptyResponse, statusCode: 200)
        ]

        let results = try await client.propose(files: files, context: Fixtures.context)

        XCTAssertEqual(mockSession.requestsMade.count, 2, "75 files should be split into 2 chunks (50 + 25)")
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Test 9: All action types decode correctly

    func testAllActionTypesDecodeCorrectly() async throws {
        let archiveFile = FileItem(
            url: URL(fileURLWithPath: "/Users/test/Downloads/app.dmg"),
            size: 1_048_576,
            createdAt: Date(timeIntervalSinceNow: -60 * 86400),
            modifiedAt: Date(timeIntervalSinceNow: -60 * 86400),
            mimeType: "application/x-apple-diskimage"
        )
        let keepFile = FileItem(
            url: URL(fileURLWithPath: "/Users/test/Downloads/currentProject.sketch"),
            size: 2_097_152,
            createdAt: Date(timeIntervalSinceNow: -1 * 86400),
            modifiedAt: Date(timeIntervalSinceNow: -1 * 86400),
            mimeType: "application/octet-stream"
        )

        let items: [[String: Any]] = [
            [
                "fileUrl": archiveFile.url.path,
                "action": ["type": "archive"],
                "confidence": "high",
                "reason": "DMG installer can be archived.",
                "appliedRuleIds": ["dmg-after-install"]
            ],
            [
                "fileUrl": keepFile.url.path,
                "action": ["type": "keep"],
                "confidence": "medium",
                "reason": "Recently modified project file.",
                "appliedRuleIds": []
            ]
        ]
        let apiResponse = try Fixtures.makeAPIResponse(items: items)
        mockSession.responseQueue = [MockURLSession.Response(data: apiResponse, statusCode: 200)]

        let results = try await client.propose(
            files: [archiveFile, keepFile],
            context: Fixtures.context
        )

        XCTAssertEqual(results.count, 2)

        let archiveResult = try XCTUnwrap(results.first(where: { $0.file.url == archiveFile.url }))
        if case .archive = archiveResult.action { } else {
            XCTFail("Expected .archive action, got \(archiveResult.action)")
        }
        XCTAssertEqual(archiveResult.appliedRuleIds, ["dmg-after-install"])

        let keepResult = try XCTUnwrap(results.first(where: { $0.file.url == keepFile.url }))
        if case .keep = keepResult.action { } else {
            XCTFail("Expected .keep action, got \(keepResult.action)")
        }
    }

    // MARK: - Test 10: Request includes correct headers

    func testRequestHeadersAreCorrect() async throws {
        let emptyResponse = try Fixtures.makeAPIResponse(items: [])
        mockSession.responseQueue = [MockURLSession.Response(data: emptyResponse, statusCode: 200)]

        _ = try await client.propose(files: [Fixtures.fileItem1], context: Fixtures.context)

        let request = try XCTUnwrap(mockSession.requestsMade.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-api-key-12345")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "prompt-caching-2024-07-31")
        XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
    }
}

// MARK: - MockClaudeClientTests

final class MockClaudeClientTests: XCTestCase {

    func testMockReturnsStubbed() async throws {
        let mock = MockClaudeClient()
        let expected = [
            PlannedItem(
                file: Fixtures.fileItem1,
                action: .archive(reason: "test"),
                confidence: .high,
                reason: "test"
            )
        ]
        mock.stubbedResult = expected

        let result = try await mock.propose(files: [Fixtures.fileItem1], context: Fixtures.context)

        XCTAssertEqual(result, expected)
        XCTAssertEqual(mock.callCount, 1)
        XCTAssertEqual(mock.lastCall?.files.first?.url, Fixtures.fileItem1.url)
    }

    func testMockThrowsConfiguredError() async throws {
        let mock = MockClaudeClient()
        mock.stubbedError = ClaudeClientError.rateLimited

        do {
            _ = try await mock.propose(files: [Fixtures.fileItem1], context: Fixtures.context)
            XCTFail("Expected error to be thrown")
        } catch ClaudeClientError.rateLimited {
            // Expected
        }

        XCTAssertEqual(mock.callCount, 1)
    }

    func testMockRecordsMultipleCalls() async throws {
        let mock = MockClaudeClient()

        _ = try await mock.propose(files: [Fixtures.fileItem1], context: Fixtures.context)
        _ = try await mock.propose(files: [Fixtures.fileItem2], context: Fixtures.context)

        XCTAssertEqual(mock.callCount, 2)
        XCTAssertEqual(mock.calls[0].files.first?.url, Fixtures.fileItem1.url)
        XCTAssertEqual(mock.calls[1].files.first?.url, Fixtures.fileItem2.url)
    }

    func testMockResetClearsState() async throws {
        let mock = MockClaudeClient()
        mock.stubbedError = ClaudeClientError.missingAPIKey
        _ = try? await mock.propose(files: [], context: Fixtures.context)

        mock.reset()

        XCTAssertEqual(mock.callCount, 0)
        XCTAssertNil(mock.stubbedError)
        XCTAssertTrue(mock.stubbedResult.isEmpty)
    }
}
