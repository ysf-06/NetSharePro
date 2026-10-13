import Foundation
import Network

enum IntegrationExamples {
    static let windowsClientSetupSteps: [String] = [
        "1. iPhone'da Kişisel Erişim Noktası'nı (hotspot) aç veya bilgisayarı aynı Wi-Fi ağına bağla.",
        "2. NetShare Pro'da 'Kalkanı Başlat' ile sunucuyu çalıştır (8080/8081).",
        "3. Windows istemcisinde telefonun IP adresini ve panelde görünen PIN'i gir.",
        "4. 'Bağlan (SOCKS5)' butonuna bas; istemci /__netshare_auth?pin=XXXX ile doğrulanır.",
        "5. Windows sistem proxy'si socks=<telefon-ip>:8080 olarak ayarlanır; trafik telefondan akar."
    ]

    static func programmaticEngineUsage(engine: ProxyEngine) async {
        do {
            try engine.start()
            print("Sunucu çalışıyor: \(engine.currentIPAddress ?? "?"):\(engine.socksPort)")
            try await Task.sleep(nanoseconds: 5_000_000_000)
            let clients = engine.sessionTracker.snapshot()
            for client in clients {
                print("\(client.displayName) — \(client.ip) — ↓\(client.bytesDownloaded) ↑\(client.bytesUploaded)")
            }
            engine.stop()
        } catch {
            print("Başlatılamadı: \(error.localizedDescription)")
        }
    }

    static func verifyControlServer(ipAddress: String, pin: String) async throws -> Bool {
        guard let authURL = URL(string: "http://\(ipAddress):\(ProtocolConstants.defaultControlPort)\(ProtocolConstants.authPath)?pin=\(pin)") else {
            return false
        }
        var authRequest = URLRequest(url: authURL, timeoutInterval: 5)
        authRequest.httpMethod = "GET"
        let (authBody, authResponse) = try await URLSession.shared.data(for: authRequest)
        guard let httpResponse = authResponse as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              String(data: authBody, encoding: .utf8) == ProtocolConstants.authSuccessBody else {
            return false
        }

        guard let pingURL = URL(string: "http://\(ipAddress):\(ProtocolConstants.defaultControlPort)\(ProtocolConstants.pingPath)") else {
            return false
        }
        var pingRequest = URLRequest(url: pingURL, timeoutInterval: 5)
        pingRequest.httpMethod = "GET"
        let (pingBody, pingResponse) = try await URLSession.shared.data(for: pingRequest)
        guard let pingHTTPResponse = pingResponse as? HTTPURLResponse,
              pingHTTPResponse.statusCode == 200,
              String(data: pingBody, encoding: .utf8) == ProtocolConstants.pongBody else {
            return false
        }
        return true
    }

    static func selfTestSOCKS5Tunnel(proxyHost: String, proxyPort: UInt16) async throws -> Bool {
        let parameters = NWParameters.tcp
        guard let endpointPort = NWEndpoint.Port(rawValue: proxyPort) else {
            return false
        }
        let connection = NWConnection(
            host: NWEndpoint.Host(proxyHost),
            port: endpointPort,
            using: parameters
        )

        func waitForReady() async throws {
            try await withCheckedThrowingContinuation { continuation in
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        continuation.resume()
                    case .failed(let error):
                        continuation.resume(throwing: error)
                    case .cancelled:
                        continuation.resume(throwing: ProxyError.connectionClosed)
                    default:
                        break
                    }
                }
                connection.start(queue: DispatchQueue(label: "netsharepro.selftest"))
            }
        }

        func receiveAll(minimum: Int) async throws -> Data {
            var collected = Data()
            while collected.count < minimum {
                let chunk = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                    connection.receive(minimumIncompleteLength: 1, maximumLength: ProtocolConstants.receiveChunkSize) { data, _, isComplete, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else if let data {
                            continuation.resume(returning: data)
                        } else if isComplete {
                            continuation.resume(throwing: ProxyError.connectionClosed)
                        } else {
                            continuation.resume(throwing: ProxyError.connectionClosed)
                        }
                    }
                }
                collected.append(chunk)
            }
            return collected
        }

        defer { connection.cancel() }
        try await waitForReady()

        let greeting = Data([0x05, 0x01, 0x00])
        connection.send(content: greeting, completion: .contentProcessed { _ in })
        let methodReply = try await receiveAll(minimum: 2)
        guard methodReply.first == 0x05, methodReply.dropFirst().first == 0x00 else {
            return false
        }

        let targetHost = Array("example.com".utf8)
        var request = Data([0x05, 0x01, 0x00, 0x03, UInt8(targetHost.count)])
        request.append(Data(targetHost))
        request.append(Data([0x00, 0x50]))
        connection.send(content: request, completion: .contentProcessed { _ in })

        let connectReply = try await receiveAll(minimum: 10)
        guard connectReply.first == 0x05, connectReply.dropFirst().first == 0x00 else {
            return false
        }
        return true
    }
}
