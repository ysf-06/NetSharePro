import Foundation
import Network

final class ProxyEngine {
    enum EngineState: Equatable {
        case idle
        case starting
        case running
        case failed(String)
    }

    let settings: SettingsStore
    let accessControl = AccessControl()
    let sessionTracker: SessionTracker
    let activityStore = ActivityStore()
    let adBlockService: AdBlockService
    let connectionRegistry = ConnectionRegistry()
    private let keychain: KeychainStore

    private var proxyServer: ProxyServer?
    private var controlServer: ControlHTTPServer?
    private let bonjourAnnouncer = BonjourAnnouncer()

    private let stateLock = NSLock()
    private var storedPIN: String
    private(set) var currentIPAddress: String?

    var pin: String {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storedPIN
    }

    static let pinKeychainKey = "netsharepro.proxy.pin"
    static let keychainService = "com.netsharepro.ios"

    init(settings: SettingsStore) {
        self.settings = settings
        let keychain = KeychainStore(service: Self.keychainService)
        self.keychain = keychain
        let storedPINValue = keychain.string(forKey: Self.pinKeychainKey) ?? Self.generatePIN()
        storedPIN = storedPINValue
        keychain.set(storedPINValue, forKey: Self.pinKeychainKey)
        sessionTracker = SessionTracker(defaultQuotaBytesProvider: { [weak settings] in
            settings?.defaultQuotaBytes
        })
        adBlockService = AdBlockService(
            enabledProvider: { [weak settings] in settings?.adBlockEnabled ?? false },
            customDomainsProvider: { [weak settings] in settings?.customBlockedDomains ?? [] }
        )
    }

    var engineState: EngineState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return internalState
    }

    var isRunning: Bool {
        engineState == .running
    }

    var deviceName: String {
        settings.deviceName
    }

    var socksPort: UInt16 {
        ProtocolConstants.defaultSocksPort
    }

    var controlPort: UInt16 {
        ProtocolConstants.defaultControlPort
    }

    private var internalState: EngineState = .idle

    func start() throws {
        stateLock.lock()
        if internalState == .running || internalState == .starting {
            stateLock.unlock()
            return
        }
        internalState = .starting
        stateLock.unlock()

        sessionTracker.clear()
        accessControl.reset()

        guard let ipAddress = NetworkInterfaceProvider.primaryIPv4Address() else {
            setState(.failed(ProxyError.networkInterfaceNotFound.localizedDescription))
            throw ProxyError.networkInterfaceNotFound
        }
        currentIPAddress = ipAddress

        let control = ControlHTTPServer(port: controlPort, engine: self)
        let proxy = ProxyServer(port: socksPort, engine: self)
        do {
            try control.start()
            try proxy.start()
        } catch {
            control.stop()
            proxy.stop()
            let reason = error.localizedDescription
            setState(.failed(ProxyError.serverStartFailed(reason).localizedDescription))
            throw ProxyError.serverStartFailed(reason)
        }

        controlServer = control
        proxyServer = proxy
        bonjourAnnouncer.start(
            serviceName: deviceName,
            txtRecord: [
                "socks": "\(socksPort)",
                "control": "\(controlPort)",
                "device": deviceName
            ]
        )
        setState(.running)
    }

    func stop() {
        guard isRunning || engineState == .starting else { return }
        bonjourAnnouncer.stop()
        proxyServer?.stop()
        controlServer?.stop()
        connectionRegistry.closeAll()
        proxyServer = nil
        controlServer = nil
        currentIPAddress = nil
        setState(.idle)
    }

    func regeneratePIN() {
        let newPIN = Self.generatePIN()
        stateLock.lock()
        storedPIN = newPIN
        stateLock.unlock()
        keychain.set(newPIN, forKey: Self.pinKeychainKey)
        accessControl.reset()
    }

    func revokeClient(_ ip: String) {
        accessControl.revoke(ip)
        connectionRegistry.closeAllConnections(for: ip)
    }

    func banClient(_ ip: String) {
        accessControl.ban(ip)
        accessControl.revoke(ip)
        connectionRegistry.closeAllConnections(for: ip)
    }

    func unbanClient(_ ip: String) {
        accessControl.unban(ip)
    }

    func connectionInfoText() -> String {
        let ip = currentIPAddress ?? "<telefon-ip>"
        return "SOCKS5: \(ip):\(socksPort)\nKontrol: \(ip):\(controlPort)\nPIN: \(self.pin)"
    }

    func openTunnel(
        client: TCPConnection,
        clientIP: String,
        host: String,
        port: UInt16,
        replyOnSuccess: Data,
        replyOnFailure: Data?,
        forwardInitialData: Data?,
        shouldRecordDomain: Bool
    ) async {
        let blocked = adBlockService.isBlocked(host)
        if blocked {
            activityStore.recordBlockedHost(host, includeInHistory: shouldRecordDomain)
            if let replyOnFailure {
                try? await client.send(replyOnFailure)
            }
            client.close()
            return
        }
        if shouldRecordDomain {
            activityStore.record(host: host, wasBlocked: false)
        }

        let target: TCPConnection
        do {
            target = try await TCPConnector.connect(
                host: host,
                port: port,
                timeout: ProtocolConstants.connectTimeout
            )
        } catch {
            if let replyOnFailure {
                try? await client.send(replyOnFailure)
            }
            client.close()
            return
        }

        if let forwardInitialData {
            try? await target.send(forwardInitialData)
        }
        if !replyOnSuccess.isEmpty {
            try? await client.send(replyOnSuccess)
        }

        let pipe = RelayPipe(client: client, target: target, clientIP: clientIP, engine: self)
        await pipe.run()
    }

    private func setState(_ newState: EngineState) {
        stateLock.lock()
        internalState = newState
        stateLock.unlock()
    }

    static func generatePIN() -> String {
        String(format: "%04d", Int.random(in: 1000...9999))
    }
}
