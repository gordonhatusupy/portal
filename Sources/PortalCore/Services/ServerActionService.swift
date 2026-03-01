import AppKit
import Darwin
import Foundation

@MainActor
public protocol ServerActionServing: AnyObject {
    func open(_ server: ServerRecord)
    func kill(_ server: ServerRecord) async throws
}

public enum ServerActionError: Error, LocalizedError {
    case failedToTerminate
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .failedToTerminate:
            return "The server could not be terminated."
        case .permissionDenied:
            return "Portal does not have permission to stop that server."
        }
    }
}

@MainActor
public final class ServerActionService: ServerActionServing {
    public init() {}

    public func open(_ server: ServerRecord) {
        NSWorkspace.shared.open(server.openURL)
    }

    public func kill(_ server: ServerRecord) async throws {
        if !processExists(server.pid) {
            return
        }

        if Darwin.kill(server.pid, SIGTERM) != 0 {
            if errno == ESRCH {
                return
            }
            if errno == EPERM {
                throw ServerActionError.permissionDenied
            }
            throw ServerActionError.failedToTerminate
        }

        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if !processExists(server.pid) {
                return
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        if processExists(server.pid) {
            if Darwin.kill(server.pid, SIGKILL) != 0 {
                if errno == ESRCH {
                    return
                }
                if errno == EPERM {
                    throw ServerActionError.permissionDenied
                }
                throw ServerActionError.failedToTerminate
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        if processExists(server.pid) {
            throw ServerActionError.failedToTerminate
        }
    }

    private func processExists(_ pid: Int32) -> Bool {
        if Darwin.kill(pid, 0) == 0 {
            return true
        }

        switch errno {
        case ESRCH:
            return false
        case EPERM:
            return true
        default:
            return true
        }
    }
}
