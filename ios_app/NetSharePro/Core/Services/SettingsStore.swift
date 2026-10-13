import Foundation
import Combine

final class SettingsStore: ObservableObject {
    static let speedLimitOptions: [(label: String, bytesPerSecond: UInt32?)] = [
        ("Sınırsız Hız", nil),
        ("256 KB/s (Yavaş)", 256 * 1024),
        ("1 MB/s (Standart)", 1_048_576),
        ("5 MB/s (Hızlı)", 5_242_880),
        ("10 MB/s (Ultra Hızlı)", 10_485_760)
    ]

    private let defaults: UserDefaults

    private enum Keys {
        static let adBlockEnabled = "netsharepro.settings.adBlockEnabled"
        static let customBlockedDomains = "netsharepro.settings.customBlockedDomains"
        static let speedLimitIndex = "netsharepro.settings.speedLimitIndex"
        static let defaultQuotaMB = "netsharepro.settings.defaultQuotaMB"
        static let deviceName = "netsharepro.settings.deviceName"
        static let keepScreenAwake = "netsharepro.settings.keepScreenAwake"
    }

    @Published var adBlockEnabled: Bool {
        didSet { defaults.set(adBlockEnabled, forKey: Keys.adBlockEnabled) }
    }

    @Published var customBlockedDomains: [String] {
        didSet { defaults.set(customBlockedDomains, forKey: Keys.customBlockedDomains) }
    }

    @Published var speedLimitIndex: Int {
        didSet { defaults.set(speedLimitIndex, forKey: Keys.speedLimitIndex) }
    }

    @Published var defaultQuotaMB: Int {
        didSet { defaults.set(defaultQuotaMB, forKey: Keys.defaultQuotaMB) }
    }

    @Published var deviceName: String {
        didSet {
            let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
            deviceName = trimmed.isEmpty ? Self.defaultDeviceName : trimmed
            defaults.set(deviceName, forKey: Keys.deviceName)
        }
    }

    @Published var keepScreenAwake: Bool {
        didSet { defaults.set(keepScreenAwake, forKey: Keys.keepScreenAwake) }
    }

    static let defaultDeviceName = "iPhone Paylaşım Noktası"

    var speedLimitBytesPerSec: UInt32? {
        guard Self.speedLimitOptions.indices.contains(speedLimitIndex) else { return nil }
        return Self.speedLimitOptions[speedLimitIndex].bytesPerSecond
    }

    var defaultQuotaBytes: Int? {
        defaultQuotaMB > 0 ? defaultQuotaMB * 1_048_576 : nil
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        adBlockEnabled = defaults.bool(forKey: Keys.adBlockEnabled)
        customBlockedDomains = defaults.stringArray(forKey: Keys.customBlockedDomains) ?? []
        let storedIndex = defaults.integer(forKey: Keys.speedLimitIndex)
        speedLimitIndex = (0..<Self.speedLimitOptions.count).contains(storedIndex) ? storedIndex : 0
        let storedQuota = defaults.integer(forKey: Keys.defaultQuotaMB)
        defaultQuotaMB = max(0, storedQuota)
        let storedName = defaults.string(forKey: Keys.deviceName)
        deviceName = (storedName?.isEmpty == false) ? storedName! : Self.defaultDeviceName
        keepScreenAwake = defaults.object(forKey: Keys.keepScreenAwake) as? Bool ?? true
    }
}
