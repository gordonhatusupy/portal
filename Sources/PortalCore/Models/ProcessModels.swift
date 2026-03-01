import Foundation

public struct ListeningSocket: Equatable, Sendable {
    public let pid: Int32
    public let processName: String
    public let host: String
    public let port: Int

    public init(pid: Int32, processName: String, host: String, port: Int) {
        self.pid = pid
        self.processName = processName
        self.host = host
        self.port = port
    }
}

public struct ProcessContext: Equatable, Sendable {
    public let pid: Int32
    public let processName: String
    public let executablePath: URL?
    public let currentWorkingDirectory: URL?
    public let startedAt: Date?

    public init(
        pid: Int32,
        processName: String,
        executablePath: URL?,
        currentWorkingDirectory: URL?,
        startedAt: Date?
    ) {
        self.pid = pid
        self.processName = processName
        self.executablePath = executablePath
        self.currentWorkingDirectory = currentWorkingDirectory
        self.startedAt = startedAt
    }
}
