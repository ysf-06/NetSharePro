import Foundation

final class HTTPProxySession {
    private let connection: TCPConnection
    private let engine: ProxyEngine
    private let clientIP: String

    init(connection: TCPConnection, engine: ProxyEngine, clientIP: String) {
        self.connection = connection
        self.engine = engine
        self.clientIP = clientIP
    }

    func run(initialData: Data) async {
        do {
            try await perform(initialData: initialData)
        } catch {
            connection.close()
        }
    }

    private func perform(initialData: Data) async throws {
        var buffer = initialData
        while buffer.count <= ProtocolConstants.maxHTTPHeaderSize {
            if HTTPRequestParser.isHeaderComplete(buffer) {
                break
            }
            let chunk = try await connection.receive()
            buffer.append(chunk)
        }
        guard let request = HTTPRequestParser.parse(buffer) else {
            throw ProxyError.malformedHandshake
        }

        if request.method == "CONNECT" {
            try await handleConnect(request)
        } else {
            try await handlePlainRequest(request)
        }
    }

    private func handleConnect(_ request: HTTPRequest) async throws {
        let parts = request.target.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let rawHost = parts.first, !rawHost.isEmpty else {
            throw ProxyError.malformedHandshake
        }
        let host = String(rawHost)
        let port: UInt16
        if parts.count > 1, let parsed = UInt16(String(parts[1])) {
            port = parsed
        } else {
            port = 443
        }

        await engine.openTunnel(
            client: connection,
            clientIP: clientIP,
            host: host,
            port: port,
            replyOnSuccess: Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8),
            replyOnFailure: Data("HTTP/1.1 502 Bad Gateway\r\n\r\n".utf8),
            forwardInitialData: nil,
            shouldRecordDomain: true
        )
    }

    private func handlePlainRequest(_ request: HTTPRequest) async throws {
        guard let components = URLComponents(string: request.target), let host = components.host else {
            let response = ControlHTTPServer.buildResponse(statusLine: "400 Bad Request", body: "bad_request")
            try await connection.send(response)
            return
        }
        let port = UInt16(components.port ?? 80)
        let forwarded = Self.originFormForwardData(for: request)

        await engine.openTunnel(
            client: connection,
            clientIP: clientIP,
            host: host,
            port: port,
            replyOnSuccess: Data(),
            replyOnFailure: nil,
            forwardInitialData: forwarded,
            shouldRecordDomain: true
        )
    }

    static func originFormForwardData(for request: HTTPRequest) -> Data {
        var components = URLComponents(string: request.target)
        components?.scheme = nil
        components?.host = nil
        components?.port = nil
        var path = components?.string ?? "/"
        if path.isEmpty {
            path = "/"
        }

        var head = "\(request.method) \(path) \(request.version)\r\n"
        var headerLines: [String] = []
        for (key, value) in request.headers {
            let lower = key.lowercased()
            if lower == "proxy-authorization" || lower == "proxy-connection" || lower == "keep-alive" {
                continue
            }
            headerLines.append("\(key): \(value)")
        }
        if request.header("connection") == nil {
            headerLines.append("Connection: close")
        }
        head += headerLines.joined(separator: "\r\n")
        head += "\r\n\r\n"

        var payload = Data(head.utf8)
        payload.append(request.remainingBody)
        return payload
    }
}
