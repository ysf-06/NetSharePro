import Foundation
import Network
import Combine

final class BonjourAnnouncer {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "netsharepro.bonjour.advertiser")

    func start(serviceName: String, txtRecord: [String: String]) {
        stop()
        let service = NWListener.Service(
            name: serviceName,
            type: ProtocolConstants.bonjourServiceType,
            domain: nil,
            txtRecord: NWTXTRecord(txtRecord)
        )
        guard let advertiser = try? NWListener(using: NWParameters(), on: .any) else { return }
        advertiser.service = service
        advertiser.newConnectionHandler = { connection in
            connection.cancel()
        }
        advertiser.start(queue: queue)
        listener = advertiser
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }
}

final class DiscoveryBrowser: ObservableObject {
    @Published private(set) var servers: [DiscoveredServer] = []
    @Published private(set) var isBrowsing = false

    private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let newBrowser = NWBrowser(
            for: .bonjour(type: ProtocolConstants.bonjourServiceType, domain: nil),
            using: parameters
        )
        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            let discovered: [DiscoveredServer] = results.compactMap { result in
                if case let .service(name, type, domain, _) = result.endpoint {
                    return DiscoveredServer(name: name, type: type, domain: domain)
                }
                return nil
            }
            DispatchQueue.main.async {
                self?.servers = discovered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        }
        newBrowser.stateUpdateHandler = { [weak self] state in
            let active: Bool
            if case .ready = state {
                active = true
            } else if case .failed = state {
                active = false
            } else if case .cancelled = state {
                active = false
            } else {
                active = true
            }
            DispatchQueue.main.async {
                self?.isBrowsing = active
            }
        }
        newBrowser.start(queue: DispatchQueue(label: "netsharepro.bonjour.browser"))
        browser = newBrowser
        isBrowsing = true
    }

    func stop() {
        browser?.cancel()
        browser = nil
        isBrowsing = false
        servers = []
    }
}
