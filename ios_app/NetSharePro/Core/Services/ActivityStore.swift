import Foundation

final class ActivityStore {
    private let lock = NSLock()
    private var events: [ActivityEvent] = []
    private var blockedCount = 0

    func record(host: String, wasBlocked: Bool) {
        guard !host.isEmpty, !Self.isIPAddress(host) else { return }
        lock.lock()
        events.append(ActivityEvent(id: UUID(), host: host, timestamp: Date(), wasBlocked: wasBlocked))
        if events.count > ProtocolConstants.activityHistoryLimit {
            events.removeFirst(events.count - ProtocolConstants.activityHistoryLimit)
        }
        if wasBlocked {
            blockedCount += 1
        }
        lock.unlock()
    }

    func recordBlockedHost(_ host: String, includeInHistory: Bool) {
        lock.lock()
        blockedCount += 1
        lock.unlock()
        if includeInHistory {
            record(host: host, wasBlocked: true)
        }
    }

    func snapshot() -> [ActivityEvent] {
        lock.lock()
        defer { lock.unlock() }
        return Array(events.reversed())
    }

    func blockedCountSnapshot() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return blockedCount
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        events.removeAll()
        blockedCount = 0
    }

    static func isIPAddress(_ host: String) -> Bool {
        let components = host.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 4 else { return false }
        return components.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    }
}
