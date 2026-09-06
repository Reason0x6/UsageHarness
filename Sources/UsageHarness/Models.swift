import AppKit
import Foundation
import SwiftUI

enum ScreenEdge: String, CaseIterable, Codable, Identifiable {
    case left, right, top, bottom

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .left: "rectangle.lefthalf.inset.filled"
        case .right: "rectangle.righthalf.inset.filled"
        case .top: "rectangle.tophalf.inset.filled"
        case .bottom: "rectangle.bottomhalf.inset.filled"
        }
    }

    var isVertical: Bool { self == .left || self == .right }

    var popoverEdge: Edge {
        switch self {
        case .left: .leading
        case .right: .trailing
        case .top: .top
        case .bottom: .bottom
        }
    }
}

struct DisplayChoice: Identifiable, Hashable {
    let id: UInt32
    let name: String
    let frameDescription: String

    init(screen: NSScreen, index: Int) {
        id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? UInt32(index)
        name = screen.localizedName.isEmpty ? "Display \(index + 1)" : screen.localizedName
        frameDescription = "\(Int(screen.frame.width)) × \(Int(screen.frame.height))"
    }
}

enum HarnessKind: String, CaseIterable, Codable, Identifiable {
    case codex, claude, copilot, gemini, opencode, aider

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        case .copilot: "Copilot"
        case .gemini: "Gemini CLI"
        case .opencode: "OpenCode"
        case .aider: "Aider"
        }
    }

    var shortMark: String {
        switch self {
        case .codex: "⌘"
        case .claude: "✳"
        case .copilot: "<>"
        case .gemini: "✦"
        case .opencode: "OC"
        case .aider: "A"
        }
    }

    var tint: Color {
        switch self {
        case .codex: Color(red: 0.15, green: 0.90, blue: 0.66)
        case .claude: Color(red: 1.00, green: 0.34, blue: 0.11)
        case .copilot: Color(red: 0.82, green: 0.98, blue: 0.12)
        case .gemini: Color(red: 0.33, green: 0.58, blue: 1.00)
        case .opencode: Color(red: 0.75, green: 0.50, blue: 1.00)
        case .aider: Color(red: 1.00, green: 0.62, blue: 0.24)
        }
    }
}

struct UsageMetric: Identifiable, Equatable {
    let id: String
    let title: String
    let fractionUsed: Double?
    let valueText: String
    let resetText: String?

    init(id: String, title: String, fractionUsed: Double?, valueText: String, resetText: String? = nil) {
        self.id = id
        self.title = title
        self.fractionUsed = fractionUsed.map { min(max($0, 0), 1) }
        self.valueText = valueText
        self.resetText = resetText
    }
}

struct HarnessUsage: Identifiable, Equatable {
    let kind: HarnessKind
    let isInstalled: Bool
    let metrics: [UsageMetric]
    let status: String
    let updatedAt: Date

    var id: HarnessKind { kind }
    var primaryFraction: Double? { metrics.first?.fractionUsed }
    var primaryValue: String { metrics.first?.valueText ?? (isInstalled ? "Ready" : "—") }
}

struct AppPreferences: Codable, Equatable {
    var displayID: UInt32?
    var edge: ScreenEdge = .right
    var refreshInterval: TimeInterval = 60
    var showUnavailableHarnesses = false
    var panelVisible = true

    static let `default` = AppPreferences()
}

enum Formatters {
    static func compactTokens(_ count: Int) -> String {
        switch count {
        case 1_000_000...: return String(format: "%.1fM", Double(count) / 1_000_000)
        case 1_000...: return String(format: "%.1fK", Double(count) / 1_000)
        default: return "\(count)"
        }
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    static func resetText(epochSeconds: Double?, afterSeconds: Double?) -> String? {
        let date: Date?
        if let epochSeconds, epochSeconds > 0 {
            date = Date(timeIntervalSince1970: epochSeconds)
        } else if let afterSeconds, afterSeconds > 0 {
            date = Date().addingTimeInterval(afterSeconds)
        } else {
            date = nil
        }
        guard let date else { return nil }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return "Resets \(relative.localizedString(for: date, relativeTo: Date()))"
    }
}
