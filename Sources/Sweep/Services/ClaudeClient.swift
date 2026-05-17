import Foundation
import os.log

// MARK: - URLSession protocol for testability

public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// MARK: - Errors

public enum ClaudeClientError: Error, LocalizedError {
    case missingAPIKey
    case httpError(statusCode: Int, body: String)
    case rateLimited
    case invalidResponse(String)
    case noToolUseBlock

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Anthropic API key not found in keychain. Please add your key in Sweep preferences."
        case .httpError(let statusCode, let body):
            return "Anthropic API returned HTTP \(statusCode): \(body)"
        case .rateLimited:
            return "Anthropic API rate limit exceeded. Please wait a moment and try again."
        case .invalidResponse(let detail):
            return "Could not parse Anthropic API response: \(detail)"
        case .noToolUseBlock:
            return "Anthropic API response did not contain a tool_use block."
        }
    }
}

// MARK: - Wire types (private)

private struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: [SystemBlock]
    let tools: [ClaudeTool]
    let toolChoice: ToolChoice
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case tools
        case toolChoice = "tool_choice"
        case messages
    }
}

private struct SystemBlock: Encodable {
    let type: String
    let text: String
    let cacheControl: CacheControl

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case cacheControl = "cache_control"
    }
}

private struct CacheControl: Encodable {
    let type: String
}

private struct ClaudeTool: Encodable {
    let name: String
    let description: String
    let inputSchema: InputSchema

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
    }
}

private struct InputSchema: Encodable {
    let type: String
    let required: [String]
    let properties: ItemsProperty

    struct ItemsProperty: Encodable {
        let items: ArrayProperty

        struct ArrayProperty: Encodable {
            let type: String
            let items: ItemSchema
        }

        struct ItemSchema: Encodable {
            let type: String
            let required: [String]
            let properties: ItemSchemaProperties

            struct ItemSchemaProperties: Encodable {
                let fileUrl: StringProperty
                let action: ActionProperty
                let confidence: EnumProperty
                let reason: StringProperty
                let appliedRuleIds: ArrayStringProperty

                enum CodingKeys: String, CodingKey {
                    case fileUrl, action, confidence, reason, appliedRuleIds
                }
            }
        }
    }
}

private struct StringProperty: Encodable {
    let type: String
}

private struct EnumProperty: Encodable {
    let type: String
    let `enum`: [String]
}

private struct ArrayStringProperty: Encodable {
    let type: String
    let items: StringProperty
}

private struct ActionProperty: Encodable {
    let type: String
    let required: [String]
    let properties: ActionPropertyFields

    struct ActionPropertyFields: Encodable {
        let type: EnumProperty
        let destination: DestinationProperty

        struct DestinationProperty: Encodable {
            let type: String
            let description: String
        }
    }
}

private struct ToolChoice: Encodable {
    let type: String
    let name: String
}

private struct ClaudeMessage: Encodable {
    let role: String
    let content: String
}

// MARK: - Response wire types

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
}

private struct ContentBlock: Decodable {
    let type: String
    let name: String?
    let input: ProposeActionsInput?
}

private struct ProposeActionsInput: Decodable {
    let items: [ResponseItem]
}

private struct ResponseItem: Decodable {
    let fileUrl: String
    let action: ResponseAction
    let confidence: String
    let reason: String
    let appliedRuleIds: [String]?

    enum CodingKeys: String, CodingKey {
        case fileUrl, action, confidence, reason, appliedRuleIds
    }
}

private struct ResponseAction: Decodable {
    let type: String
    let destination: String?
}

// MARK: - FileItem serialization helper

private struct FileItemForClaude: Encodable {
    let url: String
    let filename: String
    let `extension`: String
    let sizeMB: Double
    let ageInDays: Double
    let mimeType: String?

    init(from item: FileItem) {
        self.url = item.url.path
        self.filename = item.filename
        self.extension = item.fileExtension
        // Round to 2 decimal places for readability
        self.sizeMB = (Double(item.size) / 1_048_576 * 100).rounded() / 100
        self.ageInDays = (item.ageInDays * 10).rounded() / 10
        self.mimeType = item.mimeType
    }
}

// MARK: - ClaudeClient

public final class ClaudeClient: ClaudeClienting {

    // MARK: - Constants

    private enum Constants {
        static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
        static let model = "claude-sonnet-4-5"
        static let maxTokens = 4096
        static let apiKeyName = "anthropic_api_key"
        static let chunkSize = 50
        static let maxRetries = 3
        static let baseBackoffNanoseconds: UInt64 = 2_000_000_000  // 2 seconds
    }

    // MARK: - Properties

    private let keychainStore: KeychainStoring
    private let session: URLSessionProtocol
    private let systemPromptText: String
    /// Injectable sleep function — nanoseconds argument. Defaults to Task.sleep.
    /// Overridden in tests to avoid real delays.
    private let sleepNanoseconds: @Sendable (UInt64) async throws -> Void

    // MARK: - Init

    /// Production initialiser using `URLSession.shared` and real exponential backoff sleep.
    public convenience init(keychainStore: KeychainStoring, session: URLSession = .shared) {
        self.init(keychainStore: keychainStore, urlSession: session, sleepNanoseconds: { ns in
            try await Task.sleep(nanoseconds: ns)
        })
    }

    /// Designated initialiser — allows injection of a custom `URLSessionProtocol` and sleep
    /// function (useful in tests).
    public init(
        keychainStore: KeychainStoring,
        urlSession: URLSessionProtocol,
        sleepNanoseconds: @escaping @Sendable (UInt64) async throws -> Void = { ns in
            try await Task.sleep(nanoseconds: ns)
        }
    ) {
        self.keychainStore = keychainStore
        self.session = urlSession
        self.sleepNanoseconds = sleepNanoseconds
        self.systemPromptText = Self.loadSystemPrompt()
    }

    // MARK: - ClaudeClienting

    public func propose(files: [FileItem], context: ContextProfile) async throws -> [PlannedItem] {
        guard let apiKey = keychainStore.load(key: Constants.apiKeyName) else {
            SweepLogger.claude.error("ClaudeClient.propose: API key missing from keychain")
            throw ClaudeClientError.missingAPIKey
        }

        let contextJSON: String
        do {
            let data = try SweepJSON.encoder.encode(context)
            contextJSON = String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            SweepLogger.claude.error("ClaudeClient.propose: failed to encode ContextProfile: \(error.localizedDescription, privacy: .public)")
            throw ClaudeClientError.invalidResponse("Failed to encode context: \(error.localizedDescription)")
        }

        // Chunk files into groups of 50
        let chunks = stride(from: 0, to: files.count, by: Constants.chunkSize).map {
            Array(files[$0..<min($0 + Constants.chunkSize, files.count)])
        }

        SweepLogger.claude.info("ClaudeClient.propose: processing \(files.count) files in \(chunks.count) chunk(s)")

        var allResults: [PlannedItem] = []
        for (index, chunk) in chunks.enumerated() {
            SweepLogger.claude.debug("ClaudeClient.propose: sending chunk \(index + 1)/\(chunks.count) (\(chunk.count) files)")
            let items = try await proposeChunk(files: chunk, context: context, contextJSON: contextJSON, apiKey: apiKey)
            allResults.append(contentsOf: items)
        }

        return allResults
    }

    // MARK: - Private

    private func proposeChunk(
        files: [FileItem],
        context: ContextProfile,
        contextJSON: String,
        apiKey: String
    ) async throws -> [PlannedItem] {
        let userMessage = try buildUserMessage(files: files)
        let request = try buildRequest(
            apiKey: apiKey,
            contextJSON: contextJSON,
            userMessage: userMessage
        )

        let responseData = try await performRequestWithRetry(request: request)
        return try parseResponse(responseData: responseData, inputFiles: files, context: context)
    }

    private func buildUserMessage(files: [FileItem]) throws -> String {
        let serialized = files.map { FileItemForClaude(from: $0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(serialized)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ClaudeClientError.invalidResponse("Failed to serialize file list")
        }
        return "Please organize these files:\n\n\(json)"
    }

    private func buildRequest(apiKey: String, contextJSON: String, userMessage: String) throws -> URLRequest {
        var urlRequest = URLRequest(url: Constants.apiURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = ClaudeRequest(
            model: Constants.model,
            maxTokens: Constants.maxTokens,
            system: [
                SystemBlock(type: "text", text: systemPromptText, cacheControl: CacheControl(type: "ephemeral")),
                SystemBlock(type: "text", text: contextJSON, cacheControl: CacheControl(type: "ephemeral"))
            ],
            tools: [buildProposeTool()],
            toolChoice: ToolChoice(type: "tool", name: "propose_actions"),
            messages: [ClaudeMessage(role: "user", content: userMessage)]
        )

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(body)
        return urlRequest
    }

    private func buildProposeTool() -> ClaudeTool {
        ClaudeTool(
            name: "propose_actions",
            description: "Submit your proposed file organization actions",
            inputSchema: InputSchema(
                type: "object",
                required: ["items"],
                properties: InputSchema.ItemsProperty(
                    items: InputSchema.ItemsProperty.ArrayProperty(
                        type: "array",
                        items: InputSchema.ItemsProperty.ItemSchema(
                            type: "object",
                            required: ["fileUrl", "action", "confidence", "reason"],
                            properties: InputSchema.ItemsProperty.ItemSchema.ItemSchemaProperties(
                                fileUrl: StringProperty(type: "string"),
                                action: ActionProperty(
                                    type: "object",
                                    required: ["type"],
                                    properties: ActionProperty.ActionPropertyFields(
                                        type: EnumProperty(
                                            type: "string",
                                            enum: ["move", "archive", "reviewLater", "keep"]
                                        ),
                                        destination: ActionProperty.ActionPropertyFields.DestinationProperty(
                                            type: "string",
                                            description: "Required for 'move' actions"
                                        )
                                    )
                                ),
                                confidence: EnumProperty(
                                    type: "string",
                                    enum: ["high", "medium", "low"]
                                ),
                                reason: StringProperty(type: "string"),
                                appliedRuleIds: ArrayStringProperty(
                                    type: "array",
                                    items: StringProperty(type: "string")
                                )
                            )
                        )
                    )
                )
            )
        )
    }

    private func performRequestWithRetry(request: URLRequest) async throws -> Data {
        var lastError: Error = ClaudeClientError.rateLimited
        for attempt in 0..<Constants.maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ClaudeClientError.invalidResponse("Response is not an HTTP response")
                }

                if httpResponse.statusCode == 429 {
                    let backoffNs = Constants.baseBackoffNanoseconds << attempt  // 2s, 4s, 8s
                    SweepLogger.claude.warning("ClaudeClient: rate limited (attempt \(attempt + 1)/\(Constants.maxRetries)), backing off \(backoffNs / 1_000_000_000)s")
                    try await sleepNanoseconds(backoffNs)
                    lastError = ClaudeClientError.rateLimited
                    continue
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    let body = String(data: data, encoding: .utf8) ?? "<binary>"
                    SweepLogger.claude.error("ClaudeClient: HTTP \(httpResponse.statusCode): \(body, privacy: .public)")
                    throw ClaudeClientError.httpError(statusCode: httpResponse.statusCode, body: body)
                }

                return data

            } catch let error as ClaudeClientError {
                // Only retry on rate limit; rethrow all other ClaudeClientErrors immediately
                if case .rateLimited = error {
                    lastError = error
                    continue
                }
                throw error
            } catch {
                // Network-level errors — don't retry, just throw
                throw error
            }
        }

        throw lastError
    }

    private func parseResponse(responseData: Data, inputFiles: [FileItem], context: ContextProfile) throws -> [PlannedItem] {
        let claudeResponse: ClaudeResponse
        do {
            claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: responseData)
        } catch {
            let raw = String(data: responseData, encoding: .utf8) ?? "<binary>"
            SweepLogger.claude.error("ClaudeClient: failed to decode response: \(error.localizedDescription, privacy: .public), body: \(raw, privacy: .private)")
            throw ClaudeClientError.invalidResponse("JSON decode failed: \(error.localizedDescription)")
        }

        guard let toolUseBlock = claudeResponse.content.first(where: { $0.type == "tool_use" && $0.name == "propose_actions" }),
              let input = toolUseBlock.input else {
            SweepLogger.claude.error("ClaudeClient: no propose_actions tool_use block found in response")
            throw ClaudeClientError.noToolUseBlock
        }

        // Build a lookup from URL path → FileItem for O(1) matching
        let fileByPath: [String: FileItem] = Dictionary(
            inputFiles.map { ($0.url.path, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var results: [PlannedItem] = []
        for responseItem in input.items {
            // Map confidence string to ConfidenceTier
            guard let confidenceTier = ConfidenceTier(rawValue: responseItem.confidence) else {
                SweepLogger.claude.warning("ClaudeClient: unknown confidence '\(responseItem.confidence, privacy: .public)' for \(responseItem.fileUrl, privacy: .private) — skipping")
                continue
            }

            // Skip low-confidence items
            if confidenceTier == .low {
                SweepLogger.claude.debug("ClaudeClient: skipping low-confidence item \(responseItem.fileUrl, privacy: .private)")
                continue
            }

            // Match back to input FileItem
            guard let fileItem = fileByPath[responseItem.fileUrl] else {
                SweepLogger.claude.warning("ClaudeClient: response item '\(responseItem.fileUrl, privacy: .private)' not found in input files — skipping")
                continue
            }

            // Build ProposedAction
            let proposedAction: ProposedAction
            switch responseItem.action.type {
            case "move":
                guard let destinationPath = responseItem.action.destination, !destinationPath.isEmpty else {
                    SweepLogger.claude.warning("ClaudeClient: move action missing destination for \(responseItem.fileUrl, privacy: .private) — falling back to reviewLater")
                    proposedAction = .reviewLater(reason: responseItem.reason)
                    break
                }
                proposedAction = .move(destination: URL(fileURLWithPath: destinationPath), reason: responseItem.reason)
            case "archive":
                proposedAction = .archive(reason: responseItem.reason)
            case "reviewLater":
                proposedAction = .reviewLater(reason: responseItem.reason)
            case "keep":
                proposedAction = .keep(reason: responseItem.reason)
            default:
                SweepLogger.claude.warning("ClaudeClient: unknown action type '\(responseItem.action.type, privacy: .public)' for \(responseItem.fileUrl, privacy: .private) — skipping")
                continue
            }

            let plannedItem = PlannedItem(
                file: fileItem,
                action: proposedAction,
                confidence: confidenceTier,
                reason: responseItem.reason,
                appliedRuleIds: responseItem.appliedRuleIds ?? []
            )
            results.append(plannedItem)
        }

        SweepLogger.claude.info("ClaudeClient: parsed \(results.count) planned items from \(input.items.count) response items")
        return results
    }

    // MARK: - System prompt loading

    private static func loadSystemPrompt() -> String {
        // Attempt to load from bundle; fall back to embedded string
        if let url = Bundle.main.url(forResource: "SystemPrompt", withExtension: "md"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            return contents
        }

        // Fallback: hardcoded system prompt (kept in sync with Resources/SystemPrompt.md)
        return """
        # Sweep — File Organization Assistant

        ## Role

        You are **Sweep**, a personal file organization assistant for macOS. Your job is to analyze \
        a user's files and propose clear, safe, and helpful organization actions for each one.

        You work silently in the background. You never delete files. You never move files to \
        locations outside the user's designated folders. When in doubt, you leave things alone or \
        flag them for the user's review.

        ---

        ## Task

        You will receive a JSON array of file objects. For each file, analyze its name, type, size, \
        age, and any applicable rules or folder mappings from the context block, then propose the \
        best action. Call the `propose_actions` tool with your complete response.

        ---

        ## Confidence Tiers

        - `high`: A specific rule matches; destination is clear and unambiguous. Act automatically.
        - `medium`: Reasonable inference, but not certain. Send to Review folder for user confirmation.
        - `low`: No meaningful signal. Omit from response — leave the file alone.

        ---

        ## Hard Rules — NON-NEGOTIABLE

        1. NEVER propose to delete a file. Actions: move, archive, reviewLater, keep only.
        2. NEVER propose a destination outside the user's folderMap or ~/Documents/Sweep/.
        3. If unsure, always choose reviewLater over guessing wrong.
        4. Never touch system files, hidden files (starting with '.'), or files with no extension.
        5. Respect rule weights: high weight = high confidence; low weight = medium confidence.

        ---

        ## Output

        You MUST call the `propose_actions` tool. Do not write prose outside the tool call.
        Include fileUrl (exact path), action, confidence, reason, and appliedRuleIds for each item.
        Omit items with confidence 'low'.
        """
    }
}
