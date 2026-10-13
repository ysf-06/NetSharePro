import Foundation

final class SessionTracker {
    private final class ClientState {
        var deviceName: String?
        var bytesDownloaded = 0
        var bytesUploaded = 0
        var quotaBytes: Int?
        let connectedAt = Date()
        var lastSeenAt = Date()
        var uploadWindow: (second: TimeInterval, bytes: Int) = (0, 0)
        var downloadWindow: (second: TimeInterval, bytes: Int) = (0, 0)
    }

    private let lock = NSLock()
    private var clients: [String: ClientState] = [:]
    private let defaultQuotaBytesProvider: () -> Int?

    init(defaultQuotaBytesProvider: @escaping () -> Int? = { nil }) {
        self.defaultQuotaBytesProvider = defaultQuotaBytesProvider
    }

    func registerSessionIfNeeded(_ ip: String) {
        guard !ip.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        guard clients[ip] == nil else { return }
        let state = ClientState()
        state.quotaBytes = defaultQuotaBytesProvider()
        clients[ip] = state
    }

    func touch(_ ip: String, deviceName: String?) {
        registerSessionIfNeeded(ip)
        lock.lock()
        defer { lock.unlock() }
        guard let state = clients[ip] else { return }
        state.lastSeenAt = Date()
        if let deviceName, !deviceName.isEmpty {
            state.deviceName = deviceName
        }
    }

    func record(_ ip: String, direction: TrafficDirection, bytes: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let state = clients[ip] else { return false }
        switch direction {
        case .upload:
            state.bytesUploaded += bytes
        case .download:
            state.bytesDownloaded += bytes
        }
        state.lastSeenAt = Date()
        if let quota = state.quotaBytes {
            return state.bytesUploaded + state.bytesDownloaded >= quota
        }
        return false
    }

    func throttleDelay(
        _ ip: String,
        direction: TrafficDirection,
        bytes: Int,
        limitBytesPerSecond: UInt32
    ) -> TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        guard let state = clients[ip] else { return nil }
        let now = Date().timeIntervalSince1970
        let currentSecond = now.rounded(.down)
        switch direction {
        case .upload:
            if state.uploadWindow.second != currentSecond {
                state.uploadWindow = (currentSecond, 0)
            }
            state.uploadWindow.bytes += bytes
            if state.uploadWindow.bytes > Int(limitBytesPerSecond) {
                return 1.0 - (now - currentSecond)
            }
        case .download:
            if state.downloadWindow.second != currentSecond {
                state.downloadWindow = (currentSecond, 0)
            }
            state.downloadWindow.bytes += bytes
            if state.downloadWindow.bytes > Int(limitBytesPerSecond) {
                return 1.0 - (now - currentSecond)
            }
        }
        return nil
    }

    func setQuota(_ ip: String, megaBytes: Int?) {
        lock.lock()
        defer { lock.unlock() }
        guard let state = clients[ip] else { return }
        if let megaBytes, megaBytes > 0 {
            state.quotaBytes = megaBytes * 1_048_576
        } else {
            state.quotaBytes = nil
        }
    }

    func snapshot() -> [ConnectedClient] {
        lock.lock()
        defer { lock.unlock() }
        return clients.map { ip, state in
            ConnectedClient(
                id: ip,
                ip: ip,
                deviceName: state.deviceName,
                bytesDownloaded: state.bytesDownloaded,
                bytesUploaded: state.bytesUploaded,
                quotaBytes: state.quotaBytes,
                connectedAt: state.connectedAt,
                lastSeenAt: state.lastSeenAt
            )
        }
    }

    func totals() -> (downloaded: Int, uploaded: Int) {
        lock.lock()
        defer { lock.unlock() }
        let downloaded = clients.values.reduce(0) { $0 + $1.bytesDownloaded }
        let uploaded = clients.values.reduce(0) { $0 + $1.bytesUploaded }
        return (downloaded, uploaded)
    }

    func remove(_ ip: String) {
        lock.lock()
        defer { lock.unlock() }
        clients.removeValue(forKey: ip)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        clients.removeAll()
    }
}
