import Foundation
import Network

final class ControlHTTPServer {
    private let port: UInt16
    private weak var engine: ProxyEngine?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "netsharepro.control.server", qos: .userInitiated)
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
        guard engine != nil else {
            rawConnection.cancel()
            return
        }
        let tcp = TCPConnection(connection: rawConnection, queue: queue)
        tcp.start()
        Task { [weak self] in
            await self?.handle(tcp)
        }
    }

    private func handle(_ tcp: TCPConnection) async {
        defer { tcp.close() }
        guard let engine else { return }
        guard let headerData = await readHeaderData(tcp) else { return }
        guard let request = HTTPRequestParser.parse(headerData) else { return }
        let remoteIP = tcp.remoteIPAddress ?? ""

        switch request.path {
        case ProtocolConstants.authPath:
            await handleAuth(request: request, engine: engine, remoteIP: remoteIP, tcp: tcp)
        case ProtocolConstants.pingPath:
            await handlePing(request: request, engine: engine, remoteIP: remoteIP, tcp: tcp)
        default:
            let response = Self.buildResponse(statusLine: "404 Not Found", body: "not_found")
            try? await tcp.send(response)
        }
    }

    private func handleAuth(request: HTTPRequest, engine: ProxyEngine, remoteIP: String, tcp: TCPConnection) async {
        let query = request.queryParameters
        let presentedPIN = query["pin"] ?? ""
        let deviceName = query["device"]

        if presentedPIN == engine.pin {
            engine.accessControl.authenticate(remoteIP)
            engine.sessionTracker.registerSessionIfNeeded(remoteIP)
            engine.sessionTracker.touch(remoteIP, deviceName: deviceName)
            let response = Self.buildResponse(statusLine: "200 OK", body: ProtocolConstants.authSuccessBody)
            try? await tcp.send(response)
        } else {
            let response = Self.buildResponse(statusLine: "403 Forbidden", body: ProtocolConstants.authFailedBody)
            try? await tcp.send(response)
        }
    }

    private func handlePing(request: HTTPRequest, engine: ProxyEngine, remoteIP: String, tcp: TCPConnection) async {
        guard engine.accessControl.isAuthenticated(remoteIP) else {
            let response = Self.buildResponse(statusLine: "403 Forbidden", body: "")
            try? await tcp.send(response)
            return
        }
        let deviceName = request.queryParameters["device"]
        engine.sessionTracker.touch(remoteIP, deviceName: deviceName)
        let response = Self.buildResponse(
            statusLine: "200 OK",
            headers: ["X-Device-Name": engine.deviceName],
            body: ProtocolConstants.pongBody
        )
        try? await tcp.send(response)
    }

    private func readHeaderData(_ tcp: TCPConnection) async -> Data? {
        var buffer = Data()
        while buffer.count <= ProtocolConstants.maxHTTPHeaderSize {
            let chunk: Data
            do {
                chunk = try await tcp.receive()
            } catch {
                return nil
            }
            buffer.append(chunk)
            if HTTPRequestParser.isHeaderComplete(buffer) {
                return buffer
            }
        }
        return HTTPRequestParser.isHeaderComplete(buffer) ? buffer : nil
    }

    static func buildResponse(
        statusLine: String,
        headers: [String: String] = [:],
        body: String
    ) -> Data {
        var head = "HTTP/1.1 \(statusLine)\r\n"
        head += "Content-Length: \(body.utf8.count)\r\n"
        head += "Connection: close\r\n"
        for (key, value) in headers {
            head += "\(key): \(value)\r\n"
        }
        head += "\r\n"
        var payload = Data(head.utf8)
        payload.append(Data(body.utf8))
        return payload
    }
}
