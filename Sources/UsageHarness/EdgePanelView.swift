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
                UsageBadge(usage: usage, edge: edge)
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
                Text(isRefreshing ? "Scanning" : "No tools")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 66, height: 66)
        }
        .buttonStyle(.plain)
        .help("Scan for installed AI harnesses")
    }
}

private struct UsageBadge: View {
    let usage: HarnessUsage
    let edge: ScreenEdge
    @State private var showsDetails = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        Button {
            showsDetails.toggle()
        } label: {
            VStack(spacing: 5) {
                UsageRing(usage: usage, diameter: 54)
                Text(usage.primaryValue)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 70, height: 82)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(usage.kind.displayName) usage — click for details")
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
            UsageDetailView(usage: usage)
        }
    }
}

private struct UsageRing: View {
    let usage: HarnessUsage
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            if let progress = usage.primaryFraction {
                Circle()
                    .trim(from: 0, to: max(progress, 0.015))
                    .stroke(usage.kind.tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: usage.kind.tint.opacity(0.32), radius: 4)
            } else {
                Circle()
                    .trim(from: 0, to: 0.10)
                    .stroke(usage.isInstalled ? usage.kind.tint : .gray, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Text(usage.kind.shortMark)
                .font(.system(size: usage.kind.shortMark.count > 1 ? 13 : 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityLabel(usage.kind.displayName)
        .accessibilityValue(usage.primaryValue)
    }
}

private struct UsageDetailView: View {
    let usage: HarnessUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Text(usage.kind.shortMark)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(usage.kind.tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(usage.kind.displayName) Usage")
                        .font(.headline)
                    Text(usage.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if usage.metrics.isEmpty {
                Text(usage.isInstalled ? "Start a session, then refresh to see usage here." : "This harness was not found on your machine.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(usage.metrics) { metric in
                    MetricRow(metric: metric, tint: usage.kind.tint)
                }
            }

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
