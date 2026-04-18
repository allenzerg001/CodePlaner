import XCTest
@testable import CodePlaner

final class UsageStatsServiceTests: XCTestCase {
    var tempDir: URL!
    var dbPath: String!
    var service: UsageStatsService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UsageStatsServiceTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        dbPath = tempDir.appendingPathComponent("usage.db").path
        service = UsageStatsService(dbPath: dbPath)
    }

    override func tearDown() {
        service = nil
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func createDB() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [dbPath,
            """
            CREATE TABLE IF NOT EXISTS usage_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                client_id TEXT NOT NULL DEFAULT 'Unknown',
                provider TEXT NOT NULL,
                model TEXT NOT NULL,
                prompt_tokens INTEGER NOT NULL DEFAULT 0,
                completion_tokens INTEGER NOT NULL DEFAULT 0,
                total_tokens INTEGER NOT NULL DEFAULT 0,
                latency_ms INTEGER NOT NULL DEFAULT 0,
                cost_estimate REAL NOT NULL DEFAULT 0.0,
                timestamp TEXT NOT NULL
            );
            """
        ]
        try? process.run()
        process.waitUntilExit()
    }

    private func insertRecord(provider: String, clientId: String,
                               promptTokens: Int, completionTokens: Int,
                               totalTokens: Int, cost: Double) {
        let today = ISO8601DateFormatter().string(from: Date())
        let sql = """
            INSERT INTO usage_records
                (client_id, provider, model, prompt_tokens, completion_tokens,
                 total_tokens, latency_ms, cost_estimate, timestamp)
            VALUES ('\(clientId)', '\(provider)', 'test-model',
                    \(promptTokens), \(completionTokens),
                    \(totalTokens), 0, \(cost), '\(today)');
            """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [dbPath, sql]
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Tests

    func testFetchUsageWhenDatabaseDoesNotExist() {
        let expectation = XCTestExpectation(description: "Fetch with missing DB")
        service.fetchUsage()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.service.todayStats["total_requests"] as? Int, 0)
            XCTAssertEqual(self.service.todayStats["total_tokens"] as? Int, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func testFetchUsageSuccess() {
        createDB()
        insertRecord(provider: "bailian", clientId: "Claude Code",
                     promptTokens: 400, completionTokens: 600, totalTokens: 1000, cost: 0.01)
        insertRecord(provider: "bailian", clientId: "Claude Code",
                     promptTokens: 200, completionTokens: 300, totalTokens: 500, cost: 0.005)

        let expectation = XCTestExpectation(description: "Fetch usage stats")
        service.fetchUsage()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(self.service.todayStats["total_requests"] as? Int, 2)
            XCTAssertEqual(self.service.todayStats["total_tokens"] as? Int, 1500)
            XCTAssertEqual(self.service.todayStats["total_prompt_tokens"] as? Int, 600)
            XCTAssertEqual(self.service.todayStats["total_completion_tokens"] as? Int, 900)

            if let byProvider = self.service.todayStats["by_provider"] as? [String: Any],
               let bailian = byProvider["bailian"] as? [String: Any] {
                XCTAssertEqual(bailian["requests"] as? Int, 2)
                XCTAssertEqual(bailian["tokens"] as? Int, 1500)
            } else {
                XCTFail("by_provider missing bailian key")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }

    func testFetchUsageByClient() {
        createDB()
        insertRecord(provider: "deepseek", clientId: "Claude Code",
                     promptTokens: 100, completionTokens: 200, totalTokens: 300, cost: 0.003)
        insertRecord(provider: "deepseek", clientId: "Continue",
                     promptTokens: 50, completionTokens: 100, totalTokens: 150, cost: 0.0015)

        let expectation = XCTestExpectation(description: "Fetch by client")
        service.fetchUsage()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let byClient = self.service.todayStats["by_client"] as? [String: Any] {
                XCTAssertNotNil(byClient["Claude Code"])
                XCTAssertNotNil(byClient["Continue"])
            } else {
                XCTFail("by_client is missing")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testFetchUsageUsesRecentCache() {
        createDB()
        service = UsageStatsService(dbPath: dbPath, minimumRefreshInterval: 60)

        insertRecord(provider: "bailian", clientId: "Claude Code",
                     promptTokens: 400, completionTokens: 600, totalTokens: 1000, cost: 0.01)

        let firstExpectation = XCTestExpectation(description: "Initial fetch")
        service.fetchUsage()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(self.service.todayStats["total_requests"] as? Int, 1)
            firstExpectation.fulfill()
        }

        wait(for: [firstExpectation], timeout: 3.0)

        insertRecord(provider: "deepseek", clientId: "Continue",
                     promptTokens: 50, completionTokens: 50, totalTokens: 100, cost: 0.001)

        let secondExpectation = XCTestExpectation(description: "Cached fetch")
        service.fetchUsage()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.service.todayStats["total_requests"] as? Int, 1)
            XCTAssertEqual(self.service.todayStats["total_tokens"] as? Int, 1000)
            secondExpectation.fulfill()
        }

        wait(for: [secondExpectation], timeout: 2.0)
    }
}
