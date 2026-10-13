import Foundation

enum NetworkInterfaceProvider {
    struct InterfaceAddress {
        let name: String
        let address: String
    }

    static func allPrivateIPv4Addresses() -> [InterfaceAddress] {
        var result: [InterfaceAddress] = []
        var interfaceList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceList) == 0, let first = interfaceList else { return result }
        defer { freeifaddrs(interfaceList) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            let interface = current.pointee
            cursor = interface.ifa_next

            guard let sockaddrPointer = interface.ifa_addr else { continue }
            guard sockaddrPointer.pointee.sa_family == sa_family_t(AF_INET) else { continue }

            let name = String(cString: interface.ifa_name)
            guard name != "lo0" else { continue }

            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let status = getnameinfo(
                sockaddrPointer,
                socklen_t(sockaddrPointer.pointee.sa_len),
                &hostBuffer,
                socklen_t(hostBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard status == 0 else { continue }
            let address = String(cString: hostBuffer)
            guard !address.hasPrefix("169.254.") else { continue }
            result.append(InterfaceAddress(name: name, address: address))
        }
        return result
    }

    static func primaryIPv4Address() -> String? {
        let candidates = allPrivateIPv4Addresses()
        guard !candidates.isEmpty else { return nil }
        let ranked = candidates
            .map { (candidate: $0, score: preferenceScore(for: $0)) }
            .sorted { $0.score < $1.score }
        return ranked.first?.candidate.address
    }

    static func allAddressesSummary() -> String {
        allPrivateIPv4Addresses()
            .map { "\($0.name): \($0.address)" }
            .joined(separator: ", ")
    }

    private static func preferenceScore(for candidate: InterfaceAddress) -> Int {
        if candidate.name.hasPrefix("bridge") || candidate.address.hasPrefix("172.20.10.") {
            return 0
        }
        if candidate.name.hasPrefix("en") {
            return 1
        }
        if candidate.address.hasPrefix("192.168.") {
            return 2
        }
        if candidate.address.hasPrefix("10.") {
            return 3
        }
        return 4
    }
}
