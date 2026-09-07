import AppKit
import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore()

    @Published private(set) var usages: [HarnessUsage] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var displays: [DisplayChoice] = []

    let preferences = PreferencesStore.shared
    private let scanner = UsageScanner()
    private var timer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        refreshDisplays()
        configureTimer()
        preferences.$value
            .map(\.refreshInterval)
            .removeDuplicates()
            .sink { [weak self] _ in self?.configureTimer() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.refreshDisplays() }
            .store(in: &cancellables)
    }

    var visibleUsages: [HarnessUsage] {
        usages
    }

    var shelfItemCount: Int {
        max(1, visibleUsages.reduce(0) { $0 + $1.metrics.count })
    }

    func start() {
        Task { await refresh() }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let result = await scanner.scan()
        usages = result
        lastRefresh = Date()
        isRefreshing = false
    }

    func refreshDisplays() {
        displays = NSScreen.screens.enumerated().map { DisplayChoice(screen: $0.element, index: $0.offset) }
        if let selected = preferences.value.displayID,
           displays.contains(where: { $0.id == selected }) { return }
        preferences.value.displayID = displays.first?.id
    }

    func selectedScreen() -> NSScreen? {
        guard let displayID = preferences.value.displayID else { return NSScreen.main ?? NSScreen.screens.first }
        return NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func configureTimer() {
        timer?.cancel()
        timer = Timer.publish(every: max(preferences.value.refreshInterval, 15), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
    }
}
