import Foundation

extension Date {
    var shortDisplay: String {
        formatted(date: .abbreviated, time: .omitted)
    }

    var timeDisplay: String {
        formatted(date: .omitted, time: .shortened)
    }

    var fullDisplay: String {
        formatted(date: .abbreviated, time: .shortened)
    }

    var weekdayName: String {
        formatted(.dateTime.weekday(.wide))
    }
}

