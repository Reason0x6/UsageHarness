import Foundation

actor UsageScanner {
    private let fileManager = FileManager.default
    private let home = FileManager.default.homeDirectoryForCurrentUser

    func scan() -> [HarnessUsage] {
        [
            scanCodex(),
            scanClaude(),
            scanCopilot(),
            scanPresence(.gemini, executables: ["gemini"], directories: [".gemini"]),
            scanPresence(.opencode, executables: ["opencode"], directories: [".config/opencode", ".local/share/opencode"]),
            scanPresence(.aider, executables: ["aider"], directories: [".aider"])
        ]
    }

    private func scanCodex() -> HarnessUsage {
        let root = home.appendingPathComponent(".codex", isDirectory: true)
        let installed = executableExists(names: ["codex"]) || fileManager.fileExists(atPath: root.path)
        guard installed else { return unavailable(.codex) }

        guard let latest = newestJSONL(in: root.appendingPathComponent("sessions", isDirectory: true)),
              let text = JSONHelpers.tail(of: latest) else {
            return HarnessUsage(kind: .codex, isInstalled: true, metrics: [], status: "Installed · waiting for session data", updatedAt: Date())
        }

        let parsed = CodexUsageParser.parse(text)
        return HarnessUsage(
            kind: .codex,
            isInstalled: true,
            metrics: parsed.metrics,
            status: parsed.metrics.isEmpty ? "Installed · no usage counters found" : "Live local session data",
            updatedAt: Date()
        )
    }

    private func scanClaude() -> HarnessUsage {
        let root = home.appendingPathComponent(".claude", isDirectory: true)
        let installed = executableExists(names: ["claude"]) || fileManager.fileExists(atPath: root.path)
        guard installed else { return unavailable(.claude) }

        guard let latest = newestJSONL(in: root.appendingPathComponent("projects", isDirectory: true)),
              let text = JSONHelpers.tail(of: latest) else {
            return HarnessUsage(kind: .claude, isInstalled: true, metrics: [], status: "Installed · waiting for session data", updatedAt: Date())
        }

        let parsed = ClaudeUsageParser.parse(text)
        return HarnessUsage(
            kind: .claude,
            isInstalled: true,
            metrics: parsed.metrics,
            status: parsed.metrics.isEmpty ? "Installed · no token data found" : "Context estimate from local session",
            updatedAt: Date()
        )
    }

    private func scanCopilot() -> HarnessUsage {
        let configLocations = [
            home.appendingPathComponent(".config/github-copilot", isDirectory: true),
            home.appendingPathComponent(".config/gh-copilot", isDirectory: true),
            home.appendingPathComponent(".local/share/gh/extensions/gh-copilot", isDirectory: true)
        ]
        let installed = executableExists(names: ["github-copilot-cli", "copilot", "gh-copilot"]) ||
            configLocations.contains(where: { fileManager.fileExists(atPath: $0.path) }) ||
            editorExtensionExists(prefix: "github.copilot-")
        guard installed else { return unavailable(.copilot) }

        let metric = UsageMetric(
            id: "availability",
            title: "Local CLI",
            fractionUsed: nil,
            valueText: "Ready"
        )
        return HarnessUsage(
            kind: .copilot,
            isInstalled: true,
            metrics: [metric],
            status: "Installed · quota is not exposed locally",
            updatedAt: Date()
        )
    }

    private func unavailable(_ kind: HarnessKind) -> HarnessUsage {
        HarnessUsage(kind: kind, isInstalled: false, metrics: [], status: "Not detected", updatedAt: Date())
    }

    private func scanPresence(_ kind: HarnessKind, executables: [String], directories: [String]) -> HarnessUsage {
        let installed = executableExists(names: executables) || directories.contains {
            fileManager.fileExists(atPath: home.appendingPathComponent($0, isDirectory: true).path)
        }
        guard installed else { return unavailable(kind) }
        return HarnessUsage(
            kind: kind,
            isInstalled: true,
            metrics: [UsageMetric(id: "availability", title: "Local CLI", fractionUsed: nil, valueText: "Ready")],
            status: "Installed · quota is not exposed locally",
            updatedAt: Date()
        )
    }

    private func editorExtensionExists(prefix: String) -> Bool {
        let roots = [
            home.appendingPathComponent(".vscode/extensions", isDirectory: true),
            home.appendingPathComponent(".vscode-insiders/extensions", isDirectory: true),
            home.appendingPathComponent(".cursor/extensions", isDirectory: true)
        ]
        return roots.contains { root in
            guard let entries = try? fileManager.contentsOfDirectory(atPath: root.path) else { return false }
            return entries.contains(where: { $0.hasPrefix(prefix) })
        }
    }

    private func executableExists(names: [String]) -> Bool {
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
        let nvmVersions = home.appendingPathComponent(".nvm/versions/node", isDirectory: true)
        if let versions = try? fileManager.contentsOfDirectory(atPath: nvmVersions.path) {
            paths.append(contentsOf: versions.map { nvmVersions.appendingPathComponent($0).appendingPathComponent("bin").path })
        }
        return names.contains { name in
            paths.contains { directory in
                fileManager.isExecutableFile(atPath: URL(fileURLWithPath: directory).appendingPathComponent(name).path)
            }
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
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            let date = values.contentModificationDate ?? .distantPast
            if newest == nil || date > newest!.date { newest = (url, date) }
        }
        return newest?.url
    }
}

enum CodexUsageParser {
    static func parse(_ text: String) -> (metrics: [UsageMetric], contextTokens: Int?) {
        var rateLimits: [String: Any]?
        var tokenInfo: [String: Any]?

        for line in text.split(separator: "\n").reversed() {
            guard let root = JSONHelpers.dictionary(from: line),
                  let payload = root["payload"] as? [String: Any] else { continue }
            if rateLimits == nil { rateLimits = payload["rate_limits"] as? [String: Any] }
            if tokenInfo == nil { tokenInfo = payload["info"] as? [String: Any] }
            if rateLimits != nil && tokenInfo != nil { break }
        }

        var metrics: [UsageMetric] = []
        if let primary = rateLimits?["primary"] as? [String: Any],
           let used = number(primary["used_percent"]) {
            metrics.append(rateMetric(id: "codex-primary", title: windowTitle(primary, fallback: "Current window"), usedPercent: used, data: primary))
        }
        if let secondary = rateLimits?["secondary"] as? [String: Any],
           let used = number(secondary["used_percent"]) {
            metrics.append(rateMetric(id: "codex-secondary", title: windowTitle(secondary, fallback: "Long window"), usedPercent: used, data: secondary))
        }

        let total = JSONHelpers.int(tokenInfo, keys: "total_token_usage", "total_tokens")
        let contextLimit = JSONHelpers.int(tokenInfo, keys: "model_context_window")
        if metrics.isEmpty, let total, let contextLimit, contextLimit > 0 {
            let fraction = Double(total) / Double(contextLimit)
            metrics.append(UsageMetric(
                id: "codex-context",
                title: "Session context",
                fractionUsed: fraction,
                valueText: "\(Formatters.compactTokens(total)) / \(Formatters.compactTokens(contextLimit))"
            ))
        }
        return (metrics, total)
    }

    private static func rateMetric(id: String, title: String, usedPercent: Double, data: [String: Any]) -> UsageMetric {
        let fraction = usedPercent / 100
        return UsageMetric(
            id: id,
            title: title,
            fractionUsed: fraction,
            valueText: Formatters.percent(fraction),
            resetText: Formatters.resetText(
                epochSeconds: number(data["resets_at"]),
                afterSeconds: number(data["reset_after_seconds"])
            )
        )
    }

    private static func windowTitle(_ data: [String: Any], fallback: String) -> String {
        guard let minutes = number(data["window_minutes"]) else { return fallback }
        if minutes >= 1_440, minutes.truncatingRemainder(dividingBy: 1_440) == 0 {
            return "\(Int(minutes / 1_440))-day window"
        }
        if minutes >= 60, minutes.truncatingRemainder(dividingBy: 60) == 0 {
            return "\(Int(minutes / 60))-hour window"
        }
        return "\(Int(minutes))-minute window"
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }
}

enum ClaudeUsageParser {
    static let assumedContextWindow = 200_000

    static func parse(_ text: String) -> (metrics: [UsageMetric], tokens: Int?) {
        var latestTokens: Int?
        var outputTotal = 0

        for line in text.split(separator: "\n") {
            guard let root = JSONHelpers.dictionary(from: line),
                  let message = root["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else { continue }
            let input = integer(usage["input_tokens"])
            let cacheRead = integer(usage["cache_read_input_tokens"])
            let cacheCreated = integer(usage["cache_creation_input_tokens"])
            let output = integer(usage["output_tokens"])
            latestTokens = input + cacheRead + cacheCreated + output
            outputTotal += output
        }

        guard let latestTokens else { return ([], nil) }
        let fraction = Double(latestTokens) / Double(assumedContextWindow)
        var metrics = [UsageMetric(
            id: "claude-context",
            title: "Current context",
            fractionUsed: fraction,
            valueText: "\(Formatters.compactTokens(latestTokens)) / 200K"
        )]
        metrics.append(UsageMetric(
            id: "claude-output",
            title: "Session output",
            fractionUsed: nil,
            valueText: "\(Formatters.compactTokens(outputTotal)) tokens"
        ))
        return (metrics, latestTokens)
    }

    private static func integer(_ value: Any?) -> Int {
        (value as? NSNumber)?.intValue ?? Int(value as? String ?? "") ?? 0
    }
}
