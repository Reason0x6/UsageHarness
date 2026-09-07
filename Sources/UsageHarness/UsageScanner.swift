import Foundation

actor UsageScanner {
    private let fileManager = FileManager.default
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private var cachedAccessToken: String?
    private var lastCredentialAttempt: Date?

    func scan() async -> [HarnessUsage] {
        [await scanClaude()]
    }

    private func scanClaude() async -> HarnessUsage {
        let root = home.appendingPathComponent(".claude", isDirectory: true)
        let installed = executableExists(name: "claude") || fileManager.fileExists(atPath: root.path)

        async let quotaResult = fetchQuota()
        let session = newestJSONL(in: root.appendingPathComponent("projects", isDirectory: true))
            .flatMap { JSONHelpers.contents(of: $0) }
            .map(ClaudeUsageParser.parse)
        let quota = await quotaResult
        let available = installed || quota != nil || session != nil

        let metrics = quotaMetrics(quota) + [sessionMetric(session)]
        let status: String
        if quota != nil, session != nil {
            status = "Account limits + local session"
        } else if quota != nil {
            status = "Account limits available · no local session"
        } else if session != nil {
            status = "Local session · account limits unavailable"
        } else if available {
            status = "Claude detected · waiting for usage data"
        } else {
            status = "Claude Code not detected"
        }

        return HarnessUsage(
            kind: .claude,
            isInstalled: available,
            metrics: metrics,
            status: status,
            updatedAt: Date()
        )
    }

    private func quotaMetrics(_ quota: ClaudeQuotaSnapshot?) -> [UsageMetric] {
        [
            quotaMetric(id: "claude-five-hour", title: "5-hour window", window: quota?.fiveHour),
            quotaMetric(id: "claude-weekly", title: "Weekly window", window: quota?.sevenDay)
        ]
    }

    private func quotaMetric(id: String, title: String, window: ClaudeQuotaWindow?) -> UsageMetric {
        guard let window else {
            return UsageMetric(id: id, title: title, fractionUsed: nil, valueText: "Unavailable")
        }
        let fraction = window.utilization / 100
        return UsageMetric(
            id: id,
            title: title,
            fractionUsed: fraction,
            valueText: Formatters.percent(fraction),
            resetText: Formatters.resetText(epochSeconds: window.resetsAt?.timeIntervalSince1970, afterSeconds: nil)
        )
    }

    private func sessionMetric(_ session: ClaudeSessionUsage?) -> UsageMetric {
        guard let session else {
            return UsageMetric(
                id: "claude-session",
                title: "Session usage",
                fractionUsed: nil,
                valueText: "No recent session"
            )
        }
        return UsageMetric(
            id: "claude-session",
            title: "Session usage",
            fractionUsed: nil,
            valueText: "\(Formatters.compactTokens(session.totalTokens)) total · \(Formatters.compactTokens(session.currentContextTokens)) context"
        )
    }

    private func fetchQuota() async -> ClaudeQuotaSnapshot? {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return cachedQuota() }
        guard let token = accessToken() else { return cachedQuota() }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("UsageHarness/0.2", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let parsed = ClaudeQuotaParser.parse(data) {
                return parsed
            }
            if (response as? HTTPURLResponse)?.statusCode == 401 {
                cachedAccessToken = nil
                lastCredentialAttempt = Date()
            }
            return cachedQuota()
        } catch {
            return cachedQuota()
        }
    }

    private func cachedQuota() -> ClaudeQuotaSnapshot? {
        let stateURL = home.appendingPathComponent(".claude.json")
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return ClaudeQuotaParser.parse(data)
    }

    private func accessToken() -> String? {
        if let cachedAccessToken { return cachedAccessToken }
        if let lastCredentialAttempt, Date().timeIntervalSince(lastCredentialAttempt) < 900 { return nil }
        lastCredentialAttempt = Date()

        let credentialsURL = home.appendingPathComponent(".claude/.credentials.json")
        if let data = try? Data(contentsOf: credentialsURL),
           let token = ClaudeCredentialParser.accessToken(from: data) {
            cachedAccessToken = token
            return token
        }

        guard let data = keychainCredentials(),
              let token = ClaudeCredentialParser.accessToken(from: data) else { return nil }
        cachedAccessToken = token
        return token
    }

    private func keychainCredentials() -> Data? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return output.fileHandleForReading.readDataToEndOfFile()
        } catch {
            return nil
        }
    }

    private func executableExists(name: String) -> Bool {
        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        var paths = environmentPath.split(separator: ":").map(String.init) + [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            home.appendingPathComponent(".local/bin").path,
            home.appendingPathComponent(".bun/bin").path,
            home.appendingPathComponent("Library/pnpm").path,
            home.appendingPathComponent(".local/share/pnpm").path,
            home.appendingPathComponent(".asdf/shims").path,
            home.appendingPathComponent(".local/share/mise/shims").path
        ]

        let nvmRoot = home.appendingPathComponent(".nvm/versions/node", isDirectory: true)
        if let versions = try? fileManager.contentsOfDirectory(at: nvmRoot, includingPropertiesForKeys: nil) {
            paths.append(contentsOf: versions.map { $0.appendingPathComponent("bin").path })
        }
        return paths.contains {
            fileManager.isExecutableFile(atPath: URL(fileURLWithPath: $0).appendingPathComponent(name).path)
        }
    }

    private func newestJSONL(in directory: URL) -> URL? {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }

        var newest: (url: URL, date: Date)?
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard !url.pathComponents.contains("subagents") else { continue }
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            let date = values.contentModificationDate ?? .distantPast
            if newest == nil || date > newest!.date { newest = (url, date) }
        }
        return newest?.url
    }
}

struct ClaudeQuotaWindow: Equatable {
    let utilization: Double
    let resetsAt: Date?
}

struct ClaudeQuotaSnapshot: Equatable {
    let fiveHour: ClaudeQuotaWindow?
    let sevenDay: ClaudeQuotaWindow?
}

enum ClaudeQuotaParser {
    static func parse(_ data: Data) -> ClaudeQuotaSnapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let payload = root["cachedUsageUtilization"] as? [String: Any] ?? root
        var fiveHour = window(payload["five_hour"])
        var sevenDay = window(payload["seven_day"])

        if let limits = payload["limits"] as? [[String: Any]] {
            for limit in limits {
                let kind = limit["kind"] as? String
                let group = limit["group"] as? String
                if fiveHour == nil, (kind == "session" || kind == "five_hour" || group == "session") {
                    fiveHour = window(limit)
                }
                if sevenDay == nil, (kind == "weekly_all" || kind == "seven_day") {
                    sevenDay = window(limit)
                }
            }
        }
        guard fiveHour != nil || sevenDay != nil else { return nil }
        return ClaudeQuotaSnapshot(fiveHour: fiveHour, sevenDay: sevenDay)
    }

    private static func window(_ value: Any?) -> ClaudeQuotaWindow? {
        guard let value = value as? [String: Any] else { return nil }
        let utilization = number(value["utilization"])
            ?? number(value["used_percentage"])
            ?? number(value["percent"])
        guard let utilization else { return nil }
        let resetValue = value["resets_at"] ?? value["resetsAt"]
        let resetsAt: Date?
        if let string = resetValue as? String {
            resetsAt = parseDate(string)
        } else if let epoch = number(resetValue) {
            resetsAt = Date(timeIntervalSince1970: epoch)
        } else {
            resetsAt = nil
        }
        return ClaudeQuotaWindow(utilization: utilization, resetsAt: resetsAt)
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

enum ClaudeCredentialParser {
    static func accessToken(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let oauth = root["claudeAiOauth"] as? [String: Any],
           let token = oauth["accessToken"] as? String, !token.isEmpty {
            return token
        }
        if let token = root["accessToken"] as? String, !token.isEmpty { return token }
        return nil
    }
}

struct ClaudeSessionUsage: Equatable {
    let totalTokens: Int
    let currentContextTokens: Int
}

enum ClaudeUsageParser {
    static func parse(_ text: String) -> ClaudeSessionUsage {
        struct Record {
            let input: Int
            let cacheRead: Int
            let cacheCreated: Int
            let output: Int

            var total: Int { input + cacheRead + cacheCreated + output }
        }

        var records: [String: Record] = [:]
        var anonymousIndex = 0
        var latest = Record(input: 0, cacheRead: 0, cacheCreated: 0, output: 0)

        for line in text.split(separator: "\n") {
            guard let root = JSONHelpers.dictionary(from: line),
                  let message = root["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else { continue }

            let record = Record(
                input: integer(usage["input_tokens"]),
                cacheRead: integer(usage["cache_read_input_tokens"]),
                cacheCreated: integer(usage["cache_creation_input_tokens"]),
                output: integer(usage["output_tokens"])
            )
            latest = record
            let messageID = message["id"] as? String ?? "anonymous-\(anonymousIndex)"
            if message["id"] == nil { anonymousIndex += 1 }
            records[messageID] = record
        }

        return ClaudeSessionUsage(
            totalTokens: records.values.reduce(0) { $0 + $1.total },
            currentContextTokens: latest.total
        )
    }

    private static func integer(_ value: Any?) -> Int {
        (value as? NSNumber)?.intValue ?? Int(value as? String ?? "") ?? 0
    }
}
