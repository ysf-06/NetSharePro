import Foundation

final class RelayPipe {
    private let client: TCPConnection
    private let target: TCPConnection
    private let clientIP: String
    private let engine: ProxyEngine

    init(client: TCPConnection, target: TCPConnection, clientIP: String, engine: ProxyEngine) {
        self.client = client
        self.target = target
        self.clientIP = clientIP
        self.engine = engine
    }

    func run() async {
        async let uploadPump: Void = pump(from: client, to: target, direction: .upload)
        async let downloadPump: Void = pump(from: target, to: client, direction: .download)
        _ = await (uploadPump, downloadPump)
        client.close()
        target.close()
    }

    private func pump(from source: TCPConnection, to destination: TCPConnection, direction: TrafficDirection) async {
        while true {
            let chunk: Data
            do {
                chunk = try await source.receive()
            } catch {
                break
            }
            let byteCount = chunk.count
            guard byteCount > 0 else { break }

            do {
                try await destination.send(chunk)
            } catch {
                break
            }

            if let limit = engine.settings.speedLimitBytesPerSec,
               let delay = engine.sessionTracker.throttleDelay(
                clientIP,
                direction: direction,
                bytes: byteCount,
                limitBytesPerSecond: limit
               ) {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            if engine.sessionTracker.record(clientIP, direction: direction, bytes: byteCount) {
                break
            }
        }
        source.close()
        destination.close()
    }
}
