import PortalCore
import XCTest

final class DurationFormatterTests: XCTestCase {
    func testMinutes() {
        let startedAt = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 240)
        XCTAssertEqual(DurationFormatter.string(since: startedAt, now: now), "4m")
    }

    func testHoursAndMinutes() {
        let startedAt = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 7_440)
        XCTAssertEqual(DurationFormatter.string(since: startedAt, now: now), "2h 4m")
    }

    func testDaysAndHours() {
        let startedAt = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 97_200)
        XCTAssertEqual(DurationFormatter.string(since: startedAt, now: now), "1d 3h")
    }
}
