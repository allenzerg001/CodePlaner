import Foundation
import Combine

class UsageStatsService: ObservableObject {
    @Published var todayStats: [String: Any] = [:]
    @Published var isLoading = false

    private let dbPath: String
    private let minimumRefreshInterval: TimeInterval
    private let sqliteTimeout: TimeInterval
    private let workerQueue = DispatchQueue(label: "com.codingplan.usage-stats", qos: .utility)
    private var lastFetchAt: Date?
    private var cachedStats: [String: Any]
    private var isFetching = false
    private var refreshTimer: AnyCancellable?

    init(
        dbPath: String? = nil,
        minimumRefreshInterval: TimeInterval = 5,
        sqliteTimeout: TimeInterval = 2
    ) {
        if let dbPath = dbPath {
            self.dbPath = dbPath
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            self.dbPath = (home as NSString).appendingPathComponent(".codingplan/usage.db")
        }
        self.minimumRefreshInterval = minimumRefreshInterval
        self.sqliteTimeout = sqliteTimeout
        self.cachedStats = Self.makeEmptyStats()
        self.todayStats = self.cachedStats

        setupRefreshTimer()
    }

    private func setupRefreshTimer() {
        refreshTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchUsage()
            }
    }

    func fetchUsage() {
        workerQueue.async { [weak self] in
            guard let self = self else { return }

            if self.isFetching {
                return
            }

            if let lastFetchAt = self.lastFetchAt,
               Date().timeIntervalSince(lastFetchAt) < self.minimumRefreshInterval {
                let cachedStats = self.cachedStats
                DispatchQueue.main.async {
                    self.todayStats = cachedStats
                    self.isLoading = false
                }
                return
            }

            self.isFetching = true
            DispatchQueue.main.async {
                self.isLoading = true
            }

            let stats = self.queryStats()
            self.cachedStats = stats
            self.lastFetchAt = Date()
            self.isFetching = false

            DispatchQueue.main.async {
                self.todayStats = stats
                self.isLoading = false
            }
        }
    }

    // MARK: - Private SQLite helpers (via sqlite3 CLI)

    private static func makeEmptyStats() -> [String: Any] {
        [
            "total_requests": 0,
            "total_tokens": 0,
            "total_prompt_tokens": 0,
            "total_completion_tokens": 0,
            "total_cost": 0.0,
            "by_provider": [:] as [String: Any],
            "by_client": [:] as [String: Any]
        ]
    }

    private func runSQLite(sql: String) -> [[String: Any]]? {
        guard FileManager.default.fileExists(atPath: dbPath) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [dbPath, "-json", sql]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()  // suppress errors

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(sqliteTimeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty,
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        return rows
    }

    private func queryStats() -> [String: Any] {
        var result = Self.makeEmptyStats()

        // Summary stats
        let summarySql = """
            SELECT
              COUNT(*) as total_requests,
              COALESCE(SUM(total_tokens), 0) as total_tokens,
              COALESCE(SUM(prompt_tokens), 0) as total_prompt_tokens,
              COALESCE(SUM(completion_tokens), 0) as total_completion_tokens,
              COALESCE(SUM(cost_estimate), 0.0) as total_cost
            FROM usage
            WHERE date(timestamp) = date('now')
            """

        if let rows = runSQLite(sql: summarySql), let row = rows.first {
            result["total_requests"] = row["total_requests"] ?? 0
            result["total_tokens"] = row["total_tokens"] ?? 0
            result["total_prompt_tokens"] = row["total_prompt_tokens"] ?? 0
            result["total_completion_tokens"] = row["total_completion_tokens"] ?? 0
            result["total_cost"] = row["total_cost"] ?? 0.0
        }

        // By provider
        let providerSql = """
            SELECT provider, COUNT(*) as requests, SUM(total_tokens) as tokens
            FROM usage
            WHERE date(timestamp) = date('now')
            GROUP BY provider
            """

        if let rows = runSQLite(sql: providerSql) {
            var byProvider: [String: Any] = [:]
            for row in rows {
                if let provider = row["provider"] as? String {
                    byProvider[provider] = [
                        "requests": row["requests"] ?? 0,
                        "tokens": row["tokens"] ?? 0
                    ]
                }
            }
            result["by_provider"] = byProvider
        }

        // By client
        let clientSql = """
            SELECT client_id, COUNT(*) as requests, SUM(total_tokens) as tokens
            FROM usage
            WHERE date(timestamp) = date('now')
            GROUP BY client_id
            """

        if let rows = runSQLite(sql: clientSql) {
            var byClient: [String: Any] = [:]
            for row in rows {
                if let clientId = row["client_id"] as? String {
                    byClient[clientId] = [
                        "requests": row["requests"] ?? 0,
                        "tokens": row["tokens"] ?? 0
                    ]
                }
            }
            result["by_client"] = byClient
        }

        return result
    }
}
