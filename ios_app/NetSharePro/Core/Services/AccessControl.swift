import Foundation

final class AccessControl {
    private let lock = NSLock()
    private var authenticatedIPs: Set<String> = []
    private var bannedIPs: Set<String> = []
    private let defaults: UserDefaults
    private static let bannedStorageKey = "netsharepro.banned.ips"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bannedIPs = Set(defaults.stringArray(forKey: Self.bannedStorageKey) ?? [])
    }

    func isAuthenticated(_ ip: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return authenticatedIPs.contains(ip) && !bannedIPs.contains(ip)
    }

    func authenticate(_ ip: String) {
        guard !ip.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        if !bannedIPs.contains(ip) {
            authenticatedIPs.insert(ip)
        }
    }

    func revoke(_ ip: String) {
        lock.lock()
        defer { lock.unlock() }
        authenticatedIPs.remove(ip)
    }

    func ban(_ ip: String) {
        lock.lock()
        authenticatedIPs.remove(ip)
        bannedIPs.insert(ip)
        lock.unlock()
        defaults.set(Array(bannedIPs), forKey: Self.bannedStorageKey)
    }

    func unban(_ ip: String) {
        lock.lock()
        bannedIPs.remove(ip)
        lock.unlock()
        defaults.set(Array(bannedIPs), forKey: Self.bannedStorageKey)
    }

    func bannedIPsSnapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return bannedIPs.sorted()
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        authenticatedIPs.removeAll()
    }
}
