import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    let settings: SettingsStore

    private let engine: ProxyEngine

    init(engine: ProxyEngine, settings: SettingsStore) {
        self.engine = engine
        self.settings = settings
    }

    var pin: String {
        engine.pin
    }

    var socksPort: UInt16 {
        engine.socksPort
    }

    var controlPort: UInt16 {
        engine.controlPort
    }

    var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var interfaceSummary: String {
        NetworkInterfaceProvider.allAddressesSummary()
    }

    func regeneratePIN() {
        engine.regeneratePIN()
        objectWillChange.send()
    }
}
