import AppKit
import SwiftUI

@main
struct UsageHarnessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Usage Harness") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Usage Harness",
                        .applicationVersion: "0.2.0"
                    ])
                }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var panelController: EdgePanelController?
    private var statusItem: NSStatusItem?
    private weak var toggleShelfItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panelController = EdgePanelController()
        configureStatusItem()
        UsageStore.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent", accessibilityDescription: "Usage Harness")
        }
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Refresh Usage", action: #selector(refresh), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        let toggleItem = NSMenuItem(title: "Hide Shelf", action: #selector(toggleShelf), keyEquivalent: "h")
        menu.addItem(toggleItem)
        toggleShelfItem = toggleItem
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Usage Harness", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        toggleShelfItem?.title = PreferencesStore.shared.value.panelVisible ? "Hide Shelf" : "Show Shelf"
    }

    @objc private func refresh() {
        Task { await UsageStore.shared.refresh() }
    }

    @objc private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        let opened = NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        if !opened {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func toggleShelf() {
        panelController?.toggleVisibility()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
