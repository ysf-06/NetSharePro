import Foundation
import Network

final class ProxyServer {
    private let port: UInt16
    private weak var engine: ProxyEngine?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "netsharepro.proxy.server", qos: .userInitiated)
    private(set) var lastError: NWError?

    init(port: UInt16, engine: ProxyEngine) {
        self.port = port
        self.engine = engine
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw ProxyError.invalidPort(port)
        }
        let newListener = try NWListener(using: parameters, on: endpointPort)
        newListener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        newListener.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                self?.lastError = error
            }
        }
        newListener.start(queue: queue)
        listener = newListener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func accept(_ rawConnection: NWConnection) {
        guard let engine else {
            rawConnection.cancel()
            return
        }
        let tcp = TCPConnection(connection: rawConnection, queue: queue)
        tcp.start()
        guard let remoteIP = tcp.remoteIPAddress, !remoteIP.isEmpty else {
            tcp.close()
            return
        }
        guard engine.accessControl.isAuthenticated(remoteIP) else {
            tcp.close()
            return
        }
        engine.sessionTracker.registerSessionIfNeeded(remoteIP)
        engine.connectionRegistry.add(tcp, for: remoteIP)

        Task { [weak self] in
            await self?.dispatchProtocol(tcp, remoteIP: remoteIP, engine: engine)
        }
    }

    private func dispatchProtocol(_ tcp: TCPConnection, remoteIP: String, engine: ProxyEngine) async {
        defer { tcp.close() }
        let firstByteData: Data
        do {
            firstByteData = try await tcp.receive(minimum: 1, maximum: 1)
        } catch {
            return
        }
        guard let versionByte = firstByteData.first else { return }

        switch versionByte {
        case 0x05:
            let session = SOCKS5Session(connection: tcp, engine: engine, clientIP: remoteIP)
            await session.run()
        case 0x04:
            let session = SOCKS4Session(connection: tcp, engine: engine, clientIP: remoteIP)
            await session.run()
        default:
            let session = HTTPProxySession(connection: tcp, engine: engine, clientIP: remoteIP)
            await session.run(initialData: firstByteData)
        }
    }
}
