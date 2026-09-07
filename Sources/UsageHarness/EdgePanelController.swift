import AppKit
import Combine
import SwiftUI

@MainActor
final class EdgePanelController {
    private let store: UsageStore
    private let preferences: PreferencesStore
    private let panel: NSPanel
    private var cancellables = Set<AnyCancellable>()

    init(store: UsageStore = .shared, preferences: PreferencesStore = .shared) {
        self.store = store
        self.preferences = preferences
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel()
        observeChanges()
        updatePanel(animated: false)
    }

    func toggleVisibility() {
        preferences.value.panelVisible.toggle()
    }

    private func configurePanel() {
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: EdgePanelView(store: store))
        panel.isReleasedWhenClosed = false
        panel.setAccessibilityLabel("AI harness usage shelf")
    }

    private func observeChanges() {
        Publishers.CombineLatest(
            preferences.$value.removeDuplicates(),
            store.$usages
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.updatePanel(animated: true) }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updatePanel(animated: false) }
            .store(in: &cancellables)
    }

    private func updatePanel(animated: Bool) {
        guard preferences.value.panelVisible else {
            panel.orderOut(nil)
            return
        }
        guard let screen = store.selectedScreen() else { return }

        let edge = preferences.value.edge
        let itemCount = store.shelfItemCount
        let size: CGSize
        if edge.isVertical {
            size = CGSize(width: 106, height: min(screen.visibleFrame.height, CGFloat(itemCount * 86 + 40)))
        } else {
            size = CGSize(width: min(screen.visibleFrame.width, CGFloat(itemCount * 74 + 50)), height: 116)
        }

        let frame = screen.visibleFrame
        let origin: CGPoint
        switch edge {
        case .left:
            origin = CGPoint(x: frame.minX, y: frame.midY - size.height / 2)
        case .right:
            origin = CGPoint(x: frame.maxX - size.width, y: frame.midY - size.height / 2)
        case .top:
            origin = CGPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height)
        case .bottom:
            origin = CGPoint(x: frame.midX - size.width / 2, y: frame.minY)
        }

        let newFrame = CGRect(origin: origin, size: size)
        panel.setFrame(newFrame, display: true, animate: animated && panel.isVisible)
        panel.orderFrontRegardless()
    }
}
