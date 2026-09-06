import Combine
import Foundation

@MainActor
final class PreferencesStore: ObservableObject {
    static let shared = PreferencesStore()

    @Published var value: AppPreferences {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let key = "UsageHarness.preferences.v1"

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            value = decoded
        } else {
            value = .default
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
