import Foundation

final class ConnectionRegistry {
    private let lock = NSLock()
    private var connectionsByIP: [String: [TCPConnection]] = [:]

    func add(_ connection: TCPConnection, for ip: String) {
        lock.lock()
        connectionsByIP[ip, default: []].append(connection)
        lock.unlock()
        connection.onClose = { [weak self, weak connection] in
            guard let self, let connection else { return }
            self.remove(connection, for: ip)
        }
    }

    func closeAllConnections(for ip: String) {
        lock.lock()
        let targets = connectionsByIP[ip] ?? []
        connectionsByIP.removeValue(forKey: ip)
        lock.unlock()
        targets.forEach { $0.close() }
    }

    func closeAll() {
        lock.lock()
        let all = connectionsByIP
        connectionsByIP.removeAll()
        lock.unlock()
        all.values.flatMap { $0 }.forEach { $0.close() }
    }

    func activeConnectionCount(for ip: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return connectionsByIP[ip]?.count ?? 0
    }

    private func remove(_ connection: TCPConnection, for ip: String) {
        lock.lock()
        defer { lock.unlock() }
        guard var list = connectionsByIP[ip] else { return }
        list.removeAll { $0 === connection }
        if list.isEmpty {
            connectionsByIP.removeValue(forKey: ip)
        } else {
            connectionsByIP[ip] = list
        }
    }
}
