import SwiftUI

struct EdgePanelView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject private var preferences = PreferencesStore.shared

    private var edge: ScreenEdge { preferences.value.edge }

    var body: some View {
        Group {
            if edge.isVertical {
                VStack(spacing: 4) { panelContent }
            } else {
                HStack(spacing: 4) { panelContent }
            }
        }
        .padding(12)
        .background {
            EdgeShelfShape(edge: edge)
                .fill(.black.opacity(0.94))
                .overlay {
                    EdgeShelfShape(edge: edge)
                        .stroke(.white.opacity(0.12), lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(0.30), radius: 18, x: 0, y: 8)
        }
        .padding(edgePadding)
        .animation(.easeInOut(duration: 0.25), value: store.visibleUsages)
    }

    @ViewBuilder
    private var panelContent: some View {
        if store.visibleUsages.isEmpty {
            EmptyPanelView(isRefreshing: store.isRefreshing) {
                Task { await store.refresh() }
            }
        } else {
            ForEach(store.visibleUsages) { usage in
                ForEach(usage.metrics) { metric in
                    UsageMetricBadge(usage: usage, metric: metric, edge: edge)
                }
            }
        }
    }

    private var edgePadding: EdgeInsets {
        switch edge {
        case .left: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 10)
        case .right: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 0)
        case .top: EdgeInsets(top: 0, leading: 8, bottom: 10, trailing: 8)
        case .bottom: EdgeInsets(top: 10, leading: 8, bottom: 0, trailing: 8)
        }
    }
}

private struct EmptyPanelView: View {
    let isRefreshing: Bool
    let refresh: () -> Void

    var body: some View {
        Button(action: refresh) {
            VStack(spacing: 7) {
                Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "sparkle.magnifyingglass")
                    .font(.system(size: 22, weight: .medium))
                Text(isRefreshing ? "Scanning" : "No Claude")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 66, height: 66)
        }
        .buttonStyle(.plain)
        .help("Scan for Claude usage")
    }
}

private struct UsageMetricBadge: View {
    let usage: HarnessUsage
    let metric: UsageMetric
    let edge: ScreenEdge
    @State private var showsDetails = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        Button {
            showsDetails.toggle()
        } label: {
            VStack(spacing: 5) {
                MetricRing(usage: usage, metric: metric, diameter: 54)
                Text(metric.compactValueText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 70, height: 82)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(metric.title) — click for details")
        .onHover { hovering in
            dismissTask?.cancel()
            if hovering {
                showsDetails = true
            } else {
                dismissTask = Task {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard !Task.isCancelled else { return }
                    showsDetails = false
                }
            }
        }
        .onDisappear { dismissTask?.cancel() }
        .popover(isPresented: $showsDetails, arrowEdge: edge.popoverEdge) {
            UsageMetricDetailView(usage: usage, metric: metric)
        }
    }
}

private struct MetricRing: View {
    let usage: HarnessUsage
    let metric: UsageMetric
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            if let progress = metric.fractionUsed {
                Circle()
                    .trim(from: 0, to: max(progress, 0.015))
                    .stroke(metric.shelfTint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: metric.shelfTint.opacity(0.32), radius: 4)
            } else if metric.compactValueText != "—" {
                Circle()
                    .stroke(metric.shelfTint, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2.5, 6]))
            } else {
                Circle()
                    .trim(from: 0, to: 0.10)
                    .stroke(.gray, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Text(metric.shelfLabel)
                .font(.system(size: metric.shelfLabel.count > 2 ? 9 : 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityLabel(metric.title)
        .accessibilityValue(metric.valueText)
    }
}

private struct UsageMetricDetailView: View {
    let usage: HarnessUsage
    let metric: UsageMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Text(usage.kind.shortMark)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(metric.shelfTint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(metric.title)
                        .font(.headline)
                    Text(usage.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            MetricRow(metric: metric, tint: metric.shelfTint)

            HStack {
                Image(systemName: "clock")
                Text(usage.updatedAt, style: .relative)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(width: 340)
    }
}

private extension UsageMetric {
    var shelfLabel: String {
        switch id {
        case "claude-five-hour": "5H"
        case "claude-weekly": "7D"
        case "claude-session": "SESSION"
        default: "•"
        }
    }

    var shelfTint: Color {
        switch id {
        case "claude-five-hour": Color(red: 1.00, green: 0.34, blue: 0.11)
        case "claude-weekly": Color(red: 0.10, green: 0.88, blue: 0.60)
        case "claude-session": Color(red: 0.88, green: 0.94, blue: 0.10)
        default: .orange
        }
    }
}

private struct MetricRow: View {
    let metric: UsageMetric
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let reset = metric.resetText {
                    Text(reset)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let progress = metric.fractionUsed {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.14))
                        Capsule().fill(tint).frame(width: max(4, proxy.size.width * progress))
                    }
                }
                .frame(height: 7)
            }
            Text(metric.valueText)
                .font(.caption.weight(.medium))
                .foregroundStyle(metric.fractionUsed == nil ? Color(nsColor: .secondaryLabelColor) : Color(nsColor: .labelColor))
        }
    }
}

private struct EdgeShelfShape: Shape {
    let edge: ScreenEdge

    func path(in rect: CGRect) -> Path {
        let radius = min(30, min(rect.width, rect.height) / 3)
        var path = Path()
        switch edge {
        case .right:
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + radius), control: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .left:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .top:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - radius), control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .bottom:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}
