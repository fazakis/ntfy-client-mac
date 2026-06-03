import Foundation

final class SettingsStore {
    private enum Keys {
        static let serverURL = "serverURL"
        static let topic = "topic"
        static let soundEnabled = "soundEnabled"
        static let reconnectOnLaunch = "reconnectOnLaunch"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.serverURL: "https://ntfy.sh",
            Keys.topic: "",
            Keys.soundEnabled: true,
            Keys.reconnectOnLaunch: false
        ])
    }

    var serverURL: String {
        get { defaults.string(forKey: Keys.serverURL) ?? "https://ntfy.sh" }
        set { defaults.set(newValue, forKey: Keys.serverURL) }
    }

    var topic: String {
        get { defaults.string(forKey: Keys.topic) ?? "" }
        set { defaults.set(newValue, forKey: Keys.topic) }
    }

    var soundEnabled: Bool {
        get { defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.soundEnabled) }
    }

    var reconnectOnLaunch: Bool {
        get { defaults.object(forKey: Keys.reconnectOnLaunch) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Keys.reconnectOnLaunch) }
    }
}
