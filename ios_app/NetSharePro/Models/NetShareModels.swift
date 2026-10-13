import Foundation

struct ConnectedClient: Identifiable, Equatable {
    let id: String
    let ip: String
    let deviceName: String?
    let bytesDownloaded: Int
    let bytesUploaded: Int
    let quotaBytes: Int?
    let connectedAt: Date
    let lastSeenAt: Date

    var displayName: String {
        guard let deviceName, !deviceName.isEmpty else { return "Bilgisayar" }
        return deviceName
    }

    var isOnline: Bool {
        Date().timeIntervalSince(lastSeenAt) < ProtocolConstants.clientOnlineWindow
    }

    var usedBytes: Int {
        bytesDownloaded + bytesUploaded
    }
}

struct ActivityEvent: Identifiable, Equatable {
    let id: UUID
    let host: String
    let timestamp: Date
    let wasBlocked: Bool
}

struct DiscoveredServer: Identifiable, Equatable {
    let name: String
    let type: String
    let domain: String

    var id: String {
        "\(name).\(type).\(domain)"
    }
}
