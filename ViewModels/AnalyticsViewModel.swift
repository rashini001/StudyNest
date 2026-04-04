import Foundation
import SwiftUI
import Combine

struct DailyStudyData: Identifiable {
    let id = UUID()
    let day: String
    let minutes: Int
}

struct SubjectData: Identifiable {
    let id = UUID()
    let subject: String
    let minutes: Int
    let color: Color
}

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var weeklyData: [DailyStudyData] = []
    @Published var subjectData: [SubjectData] = []
    @Published var streakDays: Int = 0
    @Published var totalWeeklyMinutes: Int = 0
    @Published var isLoading: Bool = false

    private let subjectColors: [Color] = [
        .nestPurple, .nestPink, .blue, .orange, .green, .teal
    ]

    init() { }

    func loadAnalytics() async {
        isLoading = true
        guard let userId = AuthService.shared.currentUserId else {
            isLoading = false
            return
        }
        let sessions  = (try? await FirestoreService.shared.fetchSessions(for: userId))  ?? []
        let pomodoros = (try? await FirestoreService.shared.fetchPomodoroRecords(for: userId)) ?? []
        buildWeeklyData(sessions: sessions, pomodoros: pomodoros)
        buildSubjectData(sessions: sessions)
        calculateStreak(sessions: sessions)
        isLoading = false
    }

    // MARK: - Private helpers

    private func buildWeeklyData(sessions: [StudySession], pomodoros: [PomodoroRecord]) {
        let cal  = Calendar.current
        let days = (0..<7)
            .compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
            .reversed()

        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"

        weeklyData = days.map { day in
            let sessionMins = sessions
                .filter  { cal.isDate($0.startTime,  inSameDayAs: day) }
                .reduce(0) { $0 + $1.computedDuration }
            let pomMins = pomodoros
                .filter  { cal.isDate($0.recordedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.totalWorkMinutes }
            return DailyStudyData(day: fmt.string(from: day), minutes: sessionMins + pomMins)
        }
        totalWeeklyMinutes = weeklyData.reduce(0) { $0 + $1.minutes }
    }

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
                    color: subjectColors[safe: i % subjectColors.count] ?? .purple
                )
            }
    }

    private func calculateStreak(sessions: [StudySession]) {
        let cal = Calendar.current
        var streak    = 0
        var checkDate = Date()
        while sessions.contains(where: { cal.isDate($0.startTime, inSameDayAs: checkDate) }) {
            streak   += 1
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        streakDays = streak
    }
}
