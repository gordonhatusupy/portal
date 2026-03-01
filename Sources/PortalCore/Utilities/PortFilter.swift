import Foundation

public enum PortFilter {
    private static let blockedPorts: Set<Int> = [
        22, 25, 53, 68, 111, 123, 389, 445, 514, 631,
        3306, 5432, 6379, 11211, 27017
    ]

    public static func shouldInclude(host: String, port: Int, projectRoot: URL?) -> Bool {
        guard projectRoot != nil else { return false }
        guard isLocalAddress(host) else { return false }
        guard port > 0 else { return false }
        guard !blockedPorts.contains(port) else { return false }
        return true
    }

    public static func isLocalAddress(_ host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased()
        if ["localhost", "127.0.0.1", "::1", "0.0.0.0", "::", "*"].contains(trimmed) {
            return true
        }

        if trimmed.hasPrefix("10.") || trimmed.hasPrefix("192.168.") {
            return true
        }

        if trimmed.hasPrefix("172.") {
            let components = trimmed.split(separator: ".")
            if components.count >= 2, let second = Int(components[1]), (16...31).contains(second) {
                return true
            }
        }

        return false
    }
}
