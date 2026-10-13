import Foundation
import Network

final class TCPConnection {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let lifecycleLock = NSLock()
    private var isClosed = false
    var onClose: (() -> Void)?

    init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
    }

    var remoteIPAddress: String? {
        guard case let .hostPort(host, _) = connection.endpoint else { return nil }
        return Self.description(of: host)
    }

    var isClosedExternally: Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return isClosed
    }

    func start() {
        connection.start(queue: queue)
    }

    func receive(minimum: Int = 1, maximum: Int = ProtocolConstants.receiveChunkSize) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: minimum, maximumLength: maximum) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: ProxyError.networkFailure(String(describing: error)))
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: ProxyError.connectionClosed)
                }
            }
        }
    }

    func send(_ data: Data) async throws {
        guard !data.isEmpty else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: ProxyError.networkFailure(String(describing: error)))
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    func close() {
        lifecycleLock.lock()
        let shouldCancel = !isClosed
        isClosed = true
        lifecycleLock.unlock()
        guard shouldCancel else { return }
        connection.cancel()
        onClose?()
    }

    static func description(of host: NWEndpoint.Host) -> String? {
        switch host {
        case .ipv4(let address):
            let bytes = [UInt8](address.rawValue)
            guard bytes.count == 4 else { return nil }
            return "\(bytes[0]).\(bytes[1]).\(bytes[2]).\(bytes[3])"
        case .ipv6(let address):
            return String(describing: address)
        case .name(let name, _):
            return name
        @unknown default:
            return nil
        }
    }
}

enum TCPConnector {
    private final class OneShotContinuation<T> {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<T, Error>?
        private var isFinished = false

        func wait() async throws -> T {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if isFinished {
                    lock.unlock()
                    continuation.resume(throwing: ProxyError.connectionClosed)
                    return
                }
                self.continuation = continuation
                lock.unlock()
            }
        }

        func fulfill(_ value: T) {
            lock.lock()
            let resumeTarget = continuation
            continuation = nil
            isFinished = isFinished || resumeTarget != nil
            lock.unlock()
            resumeTarget?.resume(returning: value)
        }

        func fail(_ error: Error) {
            lock.lock()
            let resumeTarget = continuation
            continuation = nil
            isFinished = isFinished || resumeTarget != nil
            lock.unlock()
            resumeTarget?.resume(throwing: error)
        }
    }

    static func connect(host: String, port: UInt16, timeout: TimeInterval = ProtocolConstants.connectTimeout) async throws -> TCPConnection {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw ProxyError.invalidPort(port)
        }
        let waiter = OneShotContinuation<TCPConnection>()
        let parameters = NWParameters.tcp
        let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: parameters)
        let queue = DispatchQueue(label: "netshare.connector.\(host).\(port)", qos: .userInitiated)
        let tcp = TCPConnection(connection: connection, queue: queue)

        let timeoutWorkItem = DispatchWorkItem {
            tcp.close()
            waiter.fail(ProxyError.connectionTimedOut)
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                timeoutWorkItem.cancel()
                waiter.fulfill(tcp)
            case .failed(let error):
                timeoutWorkItem.cancel()
                waiter.fail(ProxyError.networkFailure(String(describing: error)))
            case .cancelled:
                timeoutWorkItem.cancel()
                waiter.fail(ProxyError.connectionClosed)
            default:
                break
            }
        }

        defer {
            connection.stateUpdateHandler = nil
            timeoutWorkItem.cancel()
        }

        tcp.start()
        return try await waiter.wait()
    }
}
