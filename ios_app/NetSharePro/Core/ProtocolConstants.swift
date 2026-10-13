import Foundation

enum ProtocolConstants {
    static let defaultSocksPort: UInt16 = 8080
    static let defaultControlPort: UInt16 = 8081

    static let authPath = "/__netshare_auth"
    static let pingPath = "/__netshare_ping"
    static let authSuccessBody = "auth_success"
    static let authFailedBody = "auth_failed"
    static let pongBody = "pong"

    static let clientOnlineWindow: TimeInterval = 6
    static let expectedPingInterval: TimeInterval = 2

    static let bonjourServiceType = "_netsharepro._tcp"

    static let maxHTTPHeaderSize = 16_384
    static let receiveChunkSize = 65_536
    static let connectTimeout: TimeInterval = 10
    static let resolveTimeout: TimeInterval = 10

    static let activityHistoryLimit = 200
    static let speedSampleLimit = 20
}

enum TrafficDirection {
    case upload
    case download
}

enum ProxyError: Error, LocalizedError {
    case connectionClosed
    case connectionTimedOut
    case invalidPort(UInt16)
    case malformedHandshake
    case invalidHostname(String)
    case networkInterfaceNotFound
    case serverStartFailed(String)
    case networkFailure(String)

    var errorDescription: String? {
        switch self {
        case .connectionClosed:
            return "Baglanti karsi taraf tarafindan kapatildi."
        case .connectionTimedOut:
            return "Baglanti zaman asimina ugradi."
        case .invalidPort(let port):
            return "Gecersiz port numarasi: \(port)"
        case .malformedHandshake:
            return "Protokol el sikmasi bozuk veya beklenmeyen veri alindi."
        case .invalidHostname(let host):
            return "Gecersiz hedef adres: \(host)"
        case .networkInterfaceNotFound:
            return "Wi-Fi veya hotspot arayuzunde gecerli bir IP adresi bulunamadi."
        case .serverStartFailed(let reason):
            return "Sunucu baslatilamadi: \(reason)"
        case .networkFailure(let reason):
            return "Ag hatasi: \(reason)"
        }
    }
}
