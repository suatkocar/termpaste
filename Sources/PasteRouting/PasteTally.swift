import Foundation

/// Image pastes routed today and the latest one, kept across launches for the menu.
public struct PasteTally: Codable, Equatable {
    /// Start of the day `today` counts.
    public var day: Date?
    public var today: Int
    public var lastApp: String?
    public var lastTime: Date?

    public init() {
        today = 0
    }

    public mutating func record(app: String, at time: Date, calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: time)
        if day != start {
            day = start
            today = 0
        }
        today += 1
        lastApp = app
        lastTime = time
    }

    /// The count for the day containing `date`; zero once that day has passed.
    public func count(on date: Date, calendar: Calendar = .current) -> Int {
        day == calendar.startOfDay(for: date) ? today : 0
    }
}
