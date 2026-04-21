import Foundation
import SwiftUI
import Combine

//Data Models

struct DailyStudyData: Identifiable {
    let id = UUID()
    let day: String
    let date: Date
    let minutes: Int
}

struct SubjectData: Identifiable {
    let id = UUID()
    let subject: String
    let minutes: Int
    let color: Color
}

struct StreakLinePoint: Identifiable {
    let id = UUID()
    let date: Date
    let dayLabel: String
    let minutes: Int
    let hasActivity: Bool
}

//ViewModel

@MainActor
final class AnalyticsViewModel: ObservableObject {

    // Bar chart
    @Published var weeklyData: [DailyStudyData] = []

    // Donut chart
    @Published var subjectData: [SubjectData] = []

    // Line chart
    @Published var streakLineData: [StreakLinePoint] = []

    // Summary stats
    @Published var streakDays: Int = 0
    @Published var totalWeeklyMinutes: Int = 0
    @Published var longestStreak: Int = 0

    @Published var isLoading: Bool = false

    private let subjectColors: [Color] = [
        .nestPurple, .nestPink, .blue, .orange, .green, .teal, .indigo, .cyan
    ]

    //Load

    func loadAnalytics() async {
        isLoading = true
        defer { isLoading = false }

        guard let userId = AuthService.shared.currentUserId else { return }

        async let sessionsFetch  = (try? await FirestoreService.shared.fetchSessions(for: userId))      ?? []
        async let pomodorosFetch = (try? await FirestoreService.shared.fetchPomodoroRecords(for: userId)) ?? []

        let sessions  = await sessionsFetch
        let pomodoros = await pomodorosFetch

        buildWeeklyData(sessions: sessions, pomodoros: pomodoros)
        buildSubjectData(sessions: sessions)
        buildStreakLineData(sessions: sessions, pomodoros: pomodoros)
        calculateStreak(sessions: sessions)
    }

    //Bar Chart

    private func buildWeeklyData(sessions: [StudySession], pomodoros: [PomodoroRecord]) {
        let cal  = Calendar.current
        let days = (0..<7)
            .compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
            .reversed()

        let barFmt = DateFormatter()
        barFmt.dateFormat = "EEE"

        weeklyData = days.map { day in
            let sessionMins = sessions
                .filter  { cal.isDate($0.startTime, inSameDayAs: day) }
                .reduce(0) { $0 + $1.computedDuration }
            let pomMins = pomodoros
                .filter  { cal.isDate($0.recordedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.totalWorkMinutes }
            return DailyStudyData(
                day:     barFmt.string(from: day),
                date:    day,
                minutes: sessionMins + pomMins
            )
        }
        totalWeeklyMinutes = weeklyData.reduce(0) { $0 + $1.minutes }
    }

    //Donut Chart

    private func buildSubjectData(sessions: [StudySession]) {
        var map: [String: Int] = [:]
        sessions.forEach { map[$0.subject, default: 0] += $0.computedDuration }
        subjectData = map
            .sorted { $0.value > $1.value }
            .enumerated()
            .map { i, pair in
                SubjectData(
                    subject: pair.key,
                    minutes: pair.value,
                    color:   subjectColors[i % subjectColors.count]
                )
            }
    }

    //Line Chart

    private func buildStreakLineData(sessions: [StudySession], pomodoros: [PomodoroRecord]) {
        let cal    = Calendar.current
        let lineFmt = DateFormatter()
        lineFmt.dateFormat = "MMM d"

        let days = (0..<30)
            .compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
            .reversed()

        streakLineData = days.map { day in
            let sessionMins = sessions
                .filter  { cal.isDate($0.startTime, inSameDayAs: day) }
                .reduce(0) { $0 + $1.computedDuration }
            let pomMins = pomodoros
                .filter  { cal.isDate($0.recordedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.totalWorkMinutes }
            let total = sessionMins + pomMins
            return StreakLinePoint(
                date:        day,
                dayLabel:    lineFmt.string(from: day),
                minutes:     total,
                hasActivity: total > 0
            )
        }
    }

    //Current + Longest Streak

    private func calculateStreak(sessions: [StudySession]) {
        let cal = Calendar.current

        var current   = 0
        var checkDate = Date()
        while sessions.contains(where: { cal.isDate($0.startTime, inSameDayAs: checkDate) }) {
            current   += 1
            checkDate  = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        streakDays = current

        let activeDays = Set(
            sessions.map { cal.startOfDay(for: $0.startTime) }
        ).sorted()

        var longest = activeDays.isEmpty ? 0 : 1
        var running = activeDays.isEmpty ? 0 : 1
        for i in 1..<activeDays.count {
            let diff = cal.dateComponents([.day], from: activeDays[i - 1], to: activeDays[i]).day ?? 0
            if diff == 1 {
                running += 1
                longest  = max(longest, running)
            } else {
                running = 1
            }
        }
        longestStreak = longest
    }
}
