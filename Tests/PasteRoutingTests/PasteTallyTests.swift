import XCTest
@testable import PasteRouting

final class PasteTallyTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    func testCountsTodayAndRemembersTheLatestPaste() {
        var tally = PasteTally()
        XCTAssertEqual(tally.count(on: date(11, 9), calendar: calendar), 0)
        tally.record(app: "Ghostty", at: date(11, 9), calendar: calendar)
        tally.record(app: "Orca", at: date(11, 14), calendar: calendar)
        XCTAssertEqual(tally.count(on: date(11, 20), calendar: calendar), 2)
        XCTAssertEqual(tally.lastApp, "Orca")
        XCTAssertEqual(tally.lastTime, date(11, 14))
    }

    func testANewDayStartsAtZero() {
        var tally = PasteTally()
        tally.record(app: "Ghostty", at: date(10, 23), calendar: calendar)
        XCTAssertEqual(tally.count(on: date(11, 8), calendar: calendar), 0, "Yesterday's pastes are not today's")
        tally.record(app: "Ghostty", at: date(11, 8), calendar: calendar)
        XCTAssertEqual(tally.count(on: date(11, 8), calendar: calendar), 1)
    }

    func testSurvivesBeingStored() throws {
        var tally = PasteTally()
        tally.record(app: "Warp", at: date(11, 10), calendar: calendar)
        let stored = try JSONEncoder().encode(tally)
        XCTAssertEqual(try JSONDecoder().decode(PasteTally.self, from: stored), tally)
    }
}
