import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = UsageStore.shared
    @ObservedObject private var preferences = PreferencesStore.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        TabView {
            placement
                .tabItem { Label("Placement", systemImage: "rectangle.on.rectangle") }
            harnesses
                .tabItem { Label("Harnesses", systemImage: "gauge.with.dots.needle.50percent") }
            general
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .padding(20)
        .frame(width: 520, height: 410)
    }

    private var placement: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsHeader(
                title: "Screen placement",
                subtitle: "Choose one display and one edge for the usage shelf."
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("DISPLAY").settingsLabel()
                Picker("Display", selection: displayBinding) {
                    ForEach(store.displays) { display in
                        Text("\(display.name) · \(display.frameDescription)").tag(Optional(display.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("EDGE").settingsLabel()
                HStack(spacing: 10) {
                    ForEach(ScreenEdge.allCases) { edge in
                        EdgeChoice(edge: edge, selected: preferences.value.edge == edge) {
                            withAnimation(.easeInOut(duration: 0.2)) { preferences.value.edge = edge }
                        }
                    }
                }
            }

            Toggle("Show the shelf", isOn: panelVisibleBinding)
            Spacer()
        }
    }

    private var harnesses: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHeader(
                title: "AI harnesses",
                subtitle: "Usage Harness reads local session telemetry and never uploads it."
            )

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(store.usages) { usage in
                        HStack(spacing: 12) {
                            Text(usage.kind.shortMark)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(usage.kind.tint)
                                .frame(width: 30, height: 30)
                                .background(usage.kind.tint.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(usage.kind.displayName).font(.body.weight(.medium))
                                Text(usage.status).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: usage.isInstalled ? "checkmark.circle.fill" : "minus.circle")
                                .foregroundColor(usage.isInstalled ? Color.green : Color(nsColor: .secondaryLabelColor))
                        }
                        .padding(.vertical, 9)
                        if usage.id != store.usages.last?.id { Divider().padding(.leading, 42) }
                    }
                }
            }
            .frame(maxHeight: 220)
            .padding(.horizontal, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 12))

            Toggle("Show harnesses that are not installed", isOn: showUnavailableBinding)
            HStack {
                Button("Scan now") { Task { await store.refresh() } }
                    .disabled(store.isRefreshing)
                if store.isRefreshing { ProgressView().controlSize(.small) }
                Spacer()
            }
            Spacer()
        }
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsHeader(
                title: "General",
                subtitle: "Control how often local usage data is refreshed."
            )

            Toggle("Launch Usage Harness at login", isOn: Binding(
                get: { launchAtLogin },
                set: updateLaunchAtLogin
            ))

            HStack {
                Text("Refresh usage")
                Spacer()
                Picker("Refresh usage", selection: refreshBinding) {
                    Text("Every 30 seconds").tag(TimeInterval(30))
                    Text("Every minute").tag(TimeInterval(60))
                    Text("Every 5 minutes").tag(TimeInterval(300))
                    Text("Every 15 minutes").tag(TimeInterval(900))
                }
                .labelsHidden()
                .frame(width: 170)
            }

            if let launchError {
                Label(launchError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Privacy").font(.headline)
                Text("Only local configuration and recent JSONL session records are read. Credentials are never read, displayed, or transmitted.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
            Spacer()
        }
    }

    private var displayBinding: Binding<UInt32?> {
        Binding(get: { preferences.value.displayID }, set: { preferences.value.displayID = $0 })
    }

    private var panelVisibleBinding: Binding<Bool> {
        Binding(get: { preferences.value.panelVisible }, set: { preferences.value.panelVisible = $0 })
    }

    private var showUnavailableBinding: Binding<Bool> {
        Binding(get: { preferences.value.showUnavailableHarnesses }, set: { preferences.value.showUnavailableHarnesses = $0 })
    }

    private var refreshBinding: Binding<TimeInterval> {
        Binding(get: { preferences.value.refreshInterval }, set: { preferences.value.refreshInterval = $0 })
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = enabled
            launchError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchError = "Launch at login could not be changed: \(error.localizedDescription)"
        }
    }
}

private struct SettingsHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.weight(.semibold))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
    }
}

private struct EdgeChoice: View {
    let edge: ScreenEdge
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: edge.systemImage)
                    .font(.system(size: 24))
                Text(edge.title).font(.caption.weight(.medium))
            }
            .foregroundStyle(selected ? Color.accentColor : Color(nsColor: .secondaryLabelColor))
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(selected ? Color.accentColor.opacity(0.12) : Color(nsColor: .separatorColor).opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private extension Text {
    func settingsLabel() -> some View {
        font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
    }
}
