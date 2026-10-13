import Foundation
import Combine

enum ByteFormatter {
    static func bytes(_ count: Int) -> String {
        let kilo = 1024.0
        let mega = kilo * 1024
        let giga = mega * 1024
        let value = Double(count)
        switch value {
        case ..<kilo:
            return "\(count) B"
        case ..<mega:
            return String(format: "%.1f KB", value / kilo)
        case ..<giga:
            return String(format: "%.2f MB", value / mega)
        default:
            return String(format: "%.2f GB", value / giga)
        }
    }

    static func kilobytesPerSecond(_ value: Double) -> String {
        if value >= 1024 {
            return String(format: "%.2f MB/s", value / 1024)
        }
        return String(format: "%.0f KB/s", value)
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    enum RunState: Equatable {
        case idle
        case starting
        case running
        case failed(String)

        var title: String {
            switch self {
            case .idle: return "Bağlantı Kapalı"
            case .starting: return "Başlatılıyor..."
            case .running: return "Kalkan Aktif"
            case .failed(let message): return "Hata: \(message)"
            }
        }
    }

    @Published private(set) var runState: RunState = .idle
    @Published private(set) var phoneIPAddress: String?
    @Published private(set) var downloadSpeedHistory: [Double] = []
    @Published private(set) var uploadSpeedHistory: [Double] = []
    @Published private(set) var currentDownloadKBps: Double = 0
    @Published private(set) var currentUploadKBps: Double = 0
    @Published private(set) var connectedClientCount = 0
    @Published private(set) var onlineClientCount = 0
    @Published private(set) var blockedDomainCount = 0
    @Published private(set) var activeConnectionCount = 0
    @Published var isPresentingQR = false

    private let engine: ProxyEngine
    private var lastTotals: (downloaded: Int, uploaded: Int) = (0, 0)
    private var refreshTimer: AnyCancellable?

    init(engine: ProxyEngine) {
        self.engine = engine
        refreshTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    var isActive: Bool {
        runState == .running
    }

    var pin: String {
        engine.pin
    }

    var deviceName: String {
        engine.deviceName
    }

    var socksPortText: String {
        String(engine.socksPort)
    }

    var controlPortText: String {
        String(engine.controlPort)
    }

    func startSharing() {
        guard !isActive else { return }
        runState = .starting
        do {
            try engine.start()
            lastTotals = engine.sessionTracker.totals()
            downloadSpeedHistory = []
            uploadSpeedHistory = []
            runState = .running
        } catch {
            runState = .failed(error.localizedDescription)
        }
    }

    func stopSharing() {
        engine.stop()
        runState = .idle
        currentDownloadKBps = 0
        currentUploadKBps = 0
        downloadSpeedHistory = []
        uploadSpeedHistory = []
    }

    func toggleShield() {
        if isActive {
            stopSharing()
        } else {
            startSharing()
        }
    }

    func refresh() {
        let totals = engine.sessionTracker.totals()
        let downDelta = Double(max(0, totals.downloaded - lastTotals.downloaded)) / 1024
        let upDelta = Double(max(0, totals.uploaded - lastTotals.uploaded)) / 1024
        lastTotals = totals

        currentDownloadKBps = downDelta
        currentUploadKBps = upDelta

        downloadSpeedHistory.append(downDelta)
        uploadSpeedHistory.append(upDelta)
        if downloadSpeedHistory.count > ProtocolConstants.speedSampleLimit {
            downloadSpeedHistory.removeFirst(downloadSpeedHistory.count - ProtocolConstants.speedSampleLimit)
        }
        if uploadSpeedHistory.count > ProtocolConstants.speedSampleLimit {
            uploadSpeedHistory.removeFirst(uploadSpeedHistory.count - ProtocolConstants.speedSampleLimit)
        }

        let clients = engine.sessionTracker.snapshot()
        connectedClientCount = clients.count
        onlineClientCount = clients.filter { $0.isOnline }.count
        blockedDomainCount = engine.activityStore.blockedCountSnapshot()

        var connectionCount = 0
        for client in clients {
            connectionCount += engine.connectionRegistry.activeConnectionCount(for: client.ip)
        }
        activeConnectionCount = connectionCount

        phoneIPAddress = engine.currentIPAddress
    }
}
