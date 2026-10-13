import Foundation
import Combine

@MainActor
final class ClientsViewModel: ObservableObject {
    @Published private(set) var clients: [ConnectedClient] = []
    @Published private(set) var bannedIPs: [String] = []
    @Published private(set) var discoveredServers: [DiscoveredServer] = []
    @Published var quotaEditingClient: ConnectedClient?
    @Published var quotaInput: String = ""
    @Published var isPresentingQuotaAlert = false

    private let engine: ProxyEngine
    private let browser: DiscoveryBrowser
    private var refreshTimer: AnyCancellable?

    init(engine: ProxyEngine, browser: DiscoveryBrowser) {
        self.engine = engine
        self.browser = browser
        refreshTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func refresh() {
        clients = engine.sessionTracker.snapshot()
            .sorted { $0.lastSeenAt > $1.lastSeenAt }
        bannedIPs = engine.accessControl.bannedIPsSnapshot()
        discoveredServers = browser.servers
    }

    func beginQuotaEditing(for client: ConnectedClient) {
        quotaEditingClient = client
        if let quota = client.quotaBytes {
            quotaInput = String(quota / 1_048_576)
        } else {
            quotaInput = ""
        }
        isPresentingQuotaAlert = true
    }

    func commitQuotaInput() {
        guard let client = quotaEditingClient else { return }
        let trimmed = quotaInput.trimmingCharacters(in: .whitespaces)
        if let megaBytes = Int(trimmed), megaBytes > 0 {
            engine.sessionTracker.setQuota(client.ip, megaBytes: megaBytes)
        } else {
            engine.sessionTracker.setQuota(client.ip, megaBytes: nil)
        }
        quotaEditingClient = nil
        quotaInput = ""
        refresh()
    }

    func revokeAccess(_ client: ConnectedClient) {
        engine.revokeClient(client.ip)
        engine.sessionTracker.remove(client.ip)
        refresh()
    }

    func banClient(_ client: ConnectedClient) {
        engine.banClient(client.ip)
        engine.sessionTracker.remove(client.ip)
        refresh()
    }

    func unban(ip: String) {
        engine.unbanClient(ip)
        refresh()
    }
}
