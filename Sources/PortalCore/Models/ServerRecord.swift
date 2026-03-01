import Foundation

public struct ServerRecord: Identifiable, Equatable, Sendable {
    public let id: String
    public let pid: Int32
    public let port: Int
    public let host: String
    public let projectRoot: URL
    public let appName: String
    public let gitBranch: String?
    public let startedAt: Date
    public let lastSeenAt: Date
    public let openURL: URL
    public let processName: String

    public init(
        id: String,
        pid: Int32,
        port: Int,
        host: String,
        projectRoot: URL,
        appName: String,
        gitBranch: String?,
        startedAt: Date,
        lastSeenAt: Date,
        openURL: URL,
        processName: String
    ) {
        self.id = id
        self.pid = pid
        self.port = port
        self.host = host
        self.projectRoot = projectRoot
        self.appName = appName
        self.gitBranch = gitBranch
        self.startedAt = startedAt
        self.lastSeenAt = lastSeenAt
        self.openURL = openURL
        self.processName = processName
    }

    public var branchDisplayText: String {
        "\(gitBranch ?? "no-git"): \(port)"
    }

    public var subtitleDisplayText: String {
        "\(gitBranch ?? "no-git") • \(openURL.absoluteString)"
    }
}
