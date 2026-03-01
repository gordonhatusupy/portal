import Foundation

public enum LsofParser {
    public static func parseListeningSockets(_ output: String) -> [ListeningSocket] {
        var sockets: [ListeningSocket] = []
        var currentPID: Int32?
        var currentCommand: String?

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard let prefix = line.first else { continue }
            let value = String(line.dropFirst())

            switch prefix {
            case "p":
                currentPID = Int32(value)
            case "c":
                currentCommand = value.isEmpty ? nil : value
            case "n":
                guard let currentPID, let endpoint = parseEndpoint(value) else { continue }
                sockets.append(
                    ListeningSocket(
                        pid: currentPID,
                        processName: currentCommand ?? "unknown",
                        host: endpoint.host,
                        port: endpoint.port
                    )
                )
            default:
                continue
            }
        }

        return sockets
    }

    public static func parseCurrentWorkingDirectory(_ output: String) -> URL? {
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard line.first == "n" else { continue }
            let value = String(line.dropFirst())
            guard value.hasPrefix("/") else { continue }
            return URL(fileURLWithPath: value, isDirectory: true)
        }
        return nil
    }

    public static func parseEndpoint(_ rawValue: String) -> (host: String, port: Int)? {
        var value = rawValue
            .replacingOccurrences(of: " (LISTEN)", with: "")
            .replacingOccurrences(of: "TCP ", with: "")

        if let arrowIndex = value.firstIndex(of: ">") {
            value = String(value[..<arrowIndex])
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.hasPrefix("[") {
            guard let closingBracketIndex = value.firstIndex(of: "]") else { return nil }
            let host = String(value[value.index(after: value.startIndex)..<closingBracketIndex])
            let remainder = value[value.index(after: closingBracketIndex)...]
            guard remainder.first == ":", let port = Int(remainder.dropFirst()) else { return nil }
            return (host, port)
        }

        guard let separatorIndex = value.lastIndex(of: ":") else { return nil }
        let host = String(value[..<separatorIndex])
        let portString = String(value[value.index(after: separatorIndex)...])
        guard let port = Int(portString) else { return nil }
        return (host, port)
    }
}
