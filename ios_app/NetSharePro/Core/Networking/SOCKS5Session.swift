import Foundation

final class SOCKS5Session {
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
        let methodCountData = try await connection.receive(minimum: 1, maximum: 1)
        guard let methodCountByte = methodCountData.first else {
            throw ProxyError.malformedHandshake
        }
        let methodCount = Int(methodCountByte)
        var methods = Data()
        if methodCount > 0 {
            methods = try await connection.receive(minimum: methodCount, maximum: methodCount)
        }
        guard methods.contains(UInt8(0x00)) else {
            try await connection.send(Data([0x05, 0xFF]))
            return
        }
        try await connection.send(Data([0x05, 0x00]))

        let requestHeader = try await connection.receive(minimum: 4, maximum: 4)
        let headerBytes = [UInt8](requestHeader)
        guard headerBytes.count == 4, headerBytes[0] == 0x05 else {
            throw ProxyError.malformedHandshake
        }
        let command = headerBytes[1]
        let addressType = headerBytes[3]
        guard command == 0x01 else {
            try await connection.send(Data([0x05, 0x07, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
            return
        }

        let target = try await readTargetAddress(addressType: addressType)
        await engine.openTunnel(
            client: connection,
            clientIP: clientIP,
            host: target.host,
            port: target.port,
            replyOnSuccess: Data([0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
            replyOnFailure: Data([0x05, 0x04, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
            forwardInitialData: nil,
            shouldRecordDomain: target.isDomain
        )
    }

    private func readTargetAddress(addressType: UInt8) async throws -> (host: String, port: UInt16, isDomain: Bool) {
        switch addressType {
        case 0x01:
            let addressData = try await connection.receive(minimum: 4, maximum: 4)
            let bytes = [UInt8](addressData)
            guard bytes.count == 4 else { throw ProxyError.malformedHandshake }
            let host = "\(bytes[0]).\(bytes[1]).\(bytes[2]).\(bytes[3])"
            return (host, try await readPort(), false)
        case 0x03:
            let lengthData = try await connection.receive(minimum: 1, maximum: 1)
            guard let lengthByte = lengthData.first, lengthByte > 0 else {
                throw ProxyError.malformedHandshake
            }
            let domainData = try await connection.receive(minimum: Int(lengthByte), maximum: Int(lengthByte))
            guard let domain = String(data: domainData, encoding: .utf8), !domain.isEmpty else {
                throw ProxyError.malformedHandshake
            }
            return (domain, try await readPort(), true)
        case 0x04:
            let addressData = try await connection.receive(minimum: 16, maximum: 16)
            let bytes = [UInt8](addressData)
            guard bytes.count == 16 else { throw ProxyError.malformedHandshake }
            var segments: [String] = []
            var index = 0
            while index < 16 {
                let word = (UInt16(bytes[index]) << 8) | UInt16(bytes[index + 1])
                segments.append(String(word, radix: 16))
                index += 2
            }
            return (segments.joined(separator: ":"), try await readPort(), false)
        default:
            throw ProxyError.malformedHandshake
        }
    }

    private func readPort() async throws -> UInt16 {
        let portData = try await connection.receive(minimum: 2, maximum: 2)
        let bytes = [UInt8](portData)
        guard bytes.count == 2 else { throw ProxyError.malformedHandshake }
        return (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
    }
}
