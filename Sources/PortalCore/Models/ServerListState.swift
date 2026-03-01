import Foundation

public enum ServerListState: Equatable, Sendable {
    case loading
    case ready([ServerRecord])
    case empty
    case softError(String)
}
