import Foundation

struct HTTPRequest {
    let method: String
    let target: String
    let version: String
    let headers: [String: String]
    let remainingBody: Data

    var path: String {
        guard let queryIndex = target.firstIndex(of: "?") else { return target }
        return String(target[..<queryIndex])
    }

    var queryParameters: [String: String] {
        HTTPRequestParser.queryParameters(of: target)
    }

    func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }
}

enum HTTPRequestParser {
    static let headerTerminator = Data("\r\n\r\n".utf8)

    static func isHeaderComplete(_ data: Data) -> Bool {
        data.range(of: headerTerminator) != nil
    }

    static func parse(_ data: Data) -> HTTPRequest? {
        guard let terminatorRange = data.range(of: headerTerminator) else { return nil }
        let headData = data.subdata(in: data.startIndex..<terminatorRange.lowerBound)
        let bodyData = data.subdata(in: terminatorRange.upperBound..<data.endIndex)
        guard let head = String(data: headData, encoding: .utf8) else { return nil }

        let lines = head.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ").map(String.init)
        guard parts.count >= 3 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty {
                headers[key] = value
            }
        }

        return HTTPRequest(
            method: parts[0].uppercased(),
            target: parts[1],
            version: parts[2],
            headers: headers,
            remainingBody: bodyData
        )
    }

    static func queryParameters(of target: String) -> [String: String] {
        guard let queryIndex = target.firstIndex(of: "?") else { return [:] }
        let query = target[target.index(after: queryIndex)...]
        var result: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let keyValue = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let rawKey = keyValue.first,
                  let key = String(rawKey).removingPercentEncoding else { continue }
            let rawValue = keyValue.count > 1 ? String(keyValue[1]) : ""
            result[key] = rawValue.removingPercentEncoding ?? rawValue
        }
        return result
    }
}
