import PortalCore
import XCTest

final class LsofParserTests: XCTestCase {
    func testParsesListeningSocketsFromFieldOutput() {
        let sample = """
        p123
        cnode
        n*:3000
        n127.0.0.1:3001
        p456
        cpython
        n[::1]:8000
        """

        let sockets = LsofParser.parseListeningSockets(sample)

        XCTAssertEqual(sockets.count, 3)
        XCTAssertEqual(sockets[0], ListeningSocket(pid: 123, processName: "node", host: "*", port: 3000))
        XCTAssertEqual(sockets[1], ListeningSocket(pid: 123, processName: "node", host: "127.0.0.1", port: 3001))
        XCTAssertEqual(sockets[2], ListeningSocket(pid: 456, processName: "python", host: "::1", port: 8000))
    }

    func testParsesCurrentWorkingDirectory() {
        let sample = """
        p123
        n/Users/gordon/projects/portal
        """

        let url = LsofParser.parseCurrentWorkingDirectory(sample)
        XCTAssertEqual(url?.path, "/Users/gordon/projects/portal")
    }
}
