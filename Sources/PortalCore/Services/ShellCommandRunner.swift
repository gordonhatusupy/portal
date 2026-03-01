import Foundation

public struct ShellCommandResult: Equatable, Sendable {
    public let stdout: String
    public let stderr: String
    public let status: Int32

    public init(stdout: String, stderr: String, status: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.status = status
    }
}

public enum ShellCommandError: Error, LocalizedError {
    case timedOut
    case failedToLaunch(String)

    public var errorDescription: String? {
        switch self {
        case .timedOut:
            return "The command timed out."
        case let .failedToLaunch(message):
            return "Failed to launch command: \(message)"
        }
    }
}

public final class ShellCommandRunner: @unchecked Sendable {
    public init() {}

    public func run(
        executable: String,
        arguments: [String],
        timeout: TimeInterval = 1.0
    ) async throws -> ShellCommandResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: ShellCommandError.failedToLaunch(error.localizedDescription))
                    return
                }

                let deadline = Date().addingTimeInterval(timeout)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.05)
                }

                var timedOut = false
                if process.isRunning {
                    timedOut = true
                    process.terminate()
                    process.waitUntilExit()
                } else {
                    process.waitUntilExit()
                }

                let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                if timedOut {
                    continuation.resume(throwing: ShellCommandError.timedOut)
                    return
                }

                continuation.resume(
                    returning: ShellCommandResult(
                        stdout: stdout,
                        stderr: stderr,
                        status: process.terminationStatus
                    )
                )
            }
        }
    }
}
