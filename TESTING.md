# Testing Strategy for Sweep

All code ships with tests. No exceptions. Here's how.

## Test-Driven Development

Each service has a protocol (e.g., `DownloadsScanning`, `ClaudeClienting`). The protocol is tested via a mock implementation.

Pattern:
```swift
protocol DownloadsScanning {
    func scan() async throws -> [FileItem]
}

struct MockDownloadsScanner: DownloadsScanning {
    var itemsToReturn: [FileItem] = []
    var shouldThrow: Error? = nil
    
    func scan() async throws -> [FileItem] {
        if let error = shouldThrow { throw error }
        return itemsToReturn
    }
}

final class DownloadsScannerTests: XCTestCase {
    func testSkipsInProgressFiles() {
        let scanner = DownloadsScanner()
        let mock = MockDownloadsScanner(itemsToReturn: [
            FileItem(url: URL(fileURLWithPath: "/tmp/file.crdownload"), ...),
            FileItem(url: URL(fileURLWithPath: "/tmp/file.txt"), ...)
        ])
        // Assert that .crdownload is filtered out
    }
}
```

## Running Tests

```bash
make test              # Run all tests
swift test -v         # Verbose output
swift test --filter FileItemTests  # Run specific tests
```

With coverage:
```bash
swift test --enable-code-coverage
```

## Coverage Targets

- **Services** (Scanner, Client, Executor, etc.): **100%** — these are the critical path
- **UI views**: **50%+** — test state changes and callbacks, not layout
- **Models**: **100%** — Codable round-trips, validation
- **Overall**: **>80%**

GitHub Actions runs coverage on every push to `main` and `claude/**` branches.

## Before You Commit

The pre-commit hook runs:
1. `swift test --quiet` — all tests must pass
2. If tests fail, the commit is blocked

This means every commit on this repo has passing tests. Period.

## PR Checklist

- [ ] Tests written for new functionality
- [ ] All tests pass (`make test`)
- [ ] Coverage hasn't dropped significantly
- [ ] No compiler warnings
- [ ] Code formatted (swiftformat)
- [ ] Commit messages follow style guide

## Mocking Pattern

Services should always be protocols. Views should inject them via init parameters, never create them directly.

Good:
```swift
struct MenuBarRoot: View {
    let scanner: DownloadsScanning
    let client: ClaudeClienting
    // ...
}
```

Bad:
```swift
struct MenuBarRoot: View {
    let scanner = DownloadsScanner()  // Can't mock
}
```

## Test File Organization

```
Tests/SweepTests/
  Services/
    DownloadsScannerTests.swift
    ClaudeClientTests.swift
    ActionExecutorTests.swift
    ...
  Models/
    FileItemTests.swift
    ProposedActionTests.swift
    ...
  Mocks/
    MockDownloadsScanner.swift
    MockClaudeClient.swift
    ...
```
