import Foundation

final class AdBlockService {
    static let defaultBlockedDomains: [String] = [
        "doubleclick.net", "googleadservices.com", "googlesyndication.com",
        "adsystem.com", "adnxs.com", "criteo.com", "taboola.com", "outbrain.com",
        "rubiconproject.com", "openx.net", "appsflyer.com", "unityads.unity3d.com",
        "applovin.com", "vungle.com", "inmobi.com", "chartboost.com", "admob.com",
        "amazon-adsystem.com", "tiktokv.com", "byteoversea.com"
    ]

    private let enabledProvider: () -> Bool
    private let customDomainsProvider: () -> [String]

    init(
        enabledProvider: @escaping () -> Bool = { false },
        customDomainsProvider: @escaping () -> [String] = { [] }
    ) {
        self.enabledProvider = enabledProvider
        self.customDomainsProvider = customDomainsProvider
    }

    func isBlocked(_ host: String?) -> Bool {
        guard let host, !host.isEmpty, enabledProvider() else { return false }
        let normalized = host.lowercased()
        for domain in Self.defaultBlockedDomains {
            if normalized == domain || normalized.hasSuffix(".\(domain)") {
                return true
            }
        }
        for domain in customDomainsProvider() {
            let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmed.isEmpty else { continue }
            if normalized == trimmed || normalized.hasSuffix(".\(trimmed)") {
                return true
            }
        }
        return false
    }
}
