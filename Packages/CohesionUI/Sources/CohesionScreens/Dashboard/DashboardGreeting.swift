/// The Dashboard's greeting: a line for the time of day, picked from a few
/// that range from plain to playful, every one naming the user. The web's
/// lines, by the same hours.
enum DashboardGreeting {
    private struct Part {
        /// The hour the part of the day starts.
        let from: Int
        /// The greeting without a name.
        let plain: String
        let lines: [(String) -> String]
    }

    /// Latest first.
    private static let parts = [
        Part(from: 21, plain: "Good evening", lines: [
            { "Good evening, \($0)" },
            { "Still at it, \($0)?" },
            { "Night shift, \($0)?" },
            { "One last thing, \($0)?" },
        ]),
        Part(from: 17, plain: "Good evening", lines: [
            { "Good evening, \($0)" },
            { "Evening, \($0)" },
            { "Winding down, \($0)?" },
            { "Home stretch, \($0)" },
        ]),
        Part(from: 12, plain: "Good afternoon", lines: [
            { "Good afternoon, \($0)" },
            { "Afternoon, \($0)" },
            { "Back at it, \($0)?" },
            { "Halfway there, \($0)" },
        ]),
        Part(from: 8, plain: "Good morning", lines: [
            { "Good morning, \($0)" },
            { "Morning, \($0)" },
            { "Fresh start, \($0)" },
            { "Let’s get going, \($0)" },
        ]),
        Part(from: 5, plain: "Good morning", lines: [
            { "Good morning, \($0)" },
            { "Early start, \($0)?" },
            { "Up with the sun, \($0)?" },
            { "Coffee first, \($0)?" },
        ]),
        Part(from: 0, plain: "Hello", lines: [
            { "Hello, \($0)" },
            { "Late night, \($0)?" },
            { "Still up, \($0)?" },
            { "Burning the midnight oil, \($0)?" },
        ]),
    ]

    /// The greeting for `hour` (0 to 23), the line chosen by `pick` (0 up to
    /// 1); without a name, the plain greeting for the hour.
    static func line(hour: Int, name: String?, pick: Double) -> String {
        let part = parts.first { hour >= $0.from } ?? parts[parts.count - 1]
        guard let name else { return part.plain }
        return part.lines[Int(pick * Double(part.lines.count)) % part.lines.count](name)
    }
}
