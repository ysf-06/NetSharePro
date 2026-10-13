import Foundation

final class SOCKS4Session {
    private let connection: TCPConnection
    private let engine: ProxyEngine
    private let clientIP: String

    init(connection: TCPConnection, engine: ProxyEngine, clientIP: String) {
        self.connection = connection
        self.engine = engine
        self.clientIP = clientIP
    }

    func run() async {
        do {
            try await performHandshake()
        } catch {
            connection.close()
        }
    }

    private func performHandshake() async throws {
        let headerData = try await connection.receive(minimum: 7, maximum: 7)
        let bytes = [UInt8](headerData)
        guard bytes.count == 7 else { throw ProxyError.malformedHandshake }

        let command = bytes[0]
        guard command == 0x01 else {
            connection.close()
            return
        }
        let port = (UInt16(bytes[1]) << 8) | UInt16(bytes[2])
        let ipBytes = [UInt8](bytes[3...6])

        _ = try await readNullTerminatedString(maxLength: 255)

        var host = "\(ipBytes[0]).\(ipBytes[1]).\(ipBytes[2]).\(ipBytes[3])"
        var isDomain = false

        if ipBytes[0] == 0, ipBytes[1] == 0, ipBytes[2] == 0, ipBytes[3] != 0 {
            let domain = try await readNullTerminatedString(maxLength: 255)
            guard !domain.isEmpty else { throw ProxyError.malformedHandshake }
            host = domain
            isDomain = true
        }

        await engine.openTunnel(
            client: connection,
            clientIP: clientIP,
            host: host,
            port: port,
            replyOnSuccess: Data([0x00, 0x5A, bytes[1], bytes[2], ipBytes[0], ipBytes[1], ipBytes[2], ipBytes[3]]),
            replyOnFailure: Data([0x00, 0x5B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
            forwardInitialData: nil,
            shouldRecordDomain: isDomain
        )
    }

    private func readNullTerminatedString(maxLength: Int) async throws -> String {
        var collected = [UInt8]()
        while collected.count <= maxLength {
            let chunk = try await connection.receive(minimum: 1, maximum: 1)
            guard let byte = chunk.first else {
                throw ProxyError.connectionClosed
            }
            if byte == 0x00 {
                return String(decoding: collected, as: UTF8.self)
            }
            collected.append(byte)
        }
        return String(decoding: collected, as: UTF8.self)
    }
}
