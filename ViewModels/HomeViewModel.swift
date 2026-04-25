import Foundation
import FirebaseAuth
import Combine
import WidgetKit

//Weekly bar model

struct WeeklyBarDay: Identifiable {
    let id      = UUID()
    let label:   String
    let date:    Date
    let minutes: Int
    var fraction: Double  = 0
    var isToday: Bool { Calendar.current.isDateInToday(date) }
}

// MARK: - ViewModel

@MainActor
final class HomeViewModel: ObservableObject {

    // Dashboard stats
    @Published var displayName:  String       = "Student"
    @Published var streakDays:   Int          = 0
    @Published var todayMinutes: Int          = 0
    @Published var pendingTasks: Int          = 0
    @Published var weeklyHours:  Int          = 0
    @Published var overdueTasks: [StudyTask]  = []

    // Weekly chart
    @Published var weeklyBars: [WeeklyBarDay] = []

    // Next upcoming session
    @Published var nextSession: StudySession? = nil

    // Today Plan data
    @Published var todaySessions:  [StudySession]   = []
    @Published var todayTasks:     [StudyTask]       = []
    @Published var todayPomodoros: [PomodoroRecord] = []

    var todayItems: [TodayItem] {
        var items: [TodayItem] =
            todaySessions.map  { .session($0)  } +
            todayTasks.map     { .task($0)     } +
            todayPomodoros.map { .pomodoro($0) }
        items.sort { $0.sortTime < $1.sortTime }
        return items
    }

    var timeOfDay: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Morning" }
        else if h < 17 { return "Afternoon" }
        else { return "Evening" }
    }

    func load() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        displayName = Auth.auth().currentUser?.displayName ?? "Student"

        async let sessionsFetch  = (try? FirestoreService.shared.fetchSessions(for: uid))        ?? []
        async let tasksFetch     = (try? FirestoreService.shared.fetchTasks(for: uid))           ?? []
        async let pomodorosFetch = (try? FirestoreService.shared.fetchPomodoroRecords(for: uid)) ?? []

        let sessions  = await sessionsFetch
        let tasks     = await tasksFetch
        let pomodoros = await pomodorosFetch

        let cal = Calendar.current
        let now = Date()

        //Today's items
        todaySessions  = sessions.filter  { cal.isDateInToday($0.startTime) }
                                 .sorted  { $0.startTime < $1.startTime }
        todayTasks     = tasks.filter     { cal.isDateInToday($0.dueDate) }
                              .sorted     { $0.dueDate < $1.dueDate }
        todayPomodoros = pomodoros.filter { cal.isDateInToday($0.recordedAt) }
                                  .sorted { $0.recordedAt < $1.recordedAt }

        // Dashboard stats
        let sessionMins  = todaySessions.reduce(0)  { $0 + $1.computedDuration }
        let pomodoroMins = todayPomodoros.reduce(0) { $0 + $1.totalWorkMinutes }
        todayMinutes = sessionMins + pomodoroMins

        pendingTasks = tasks.filter { !$0.isCompleted }.count
        overdueTasks = tasks.filter { $0.isOverdue }

        let weekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now
        weeklyHours = sessions
            .filter   { $0.startTime > weekAgo }
            .reduce(0) { $0 + $1.computedDuration } / 60

        // Streak
        var streak    = 0
        var checkDate = now
        while sessions.contains(where: { cal.isDate($0.startTime, inSameDayAs: checkDate) }) {
            streak   += 1
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        streakDays = streak

        //Next upcoming session
        nextSession = sessions
            .filter { !$0.isCompleted && $0.startTime > now }
            .sorted { $0.startTime < $1.startTime }
            .first

        //Real weekly bars
        weeklyBars = buildWeeklyBars(sessions: sessions, pomodoros: pomodoros, cal: cal, now: now)

        // Widget
        pushWidgetSnapshot(sessions: sessions, tasks: tasks)
    }

    

    private func buildWeeklyBars(
        sessions:  [StudySession],
        pomodoros: [PomodoroRecord],
        cal:       Calendar,
        now:       Date
    ) -> [WeeklyBarDay] {

        var comps     = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 2                                         // Monday
        let weekStart = cal.date(from: comps) ?? now

        let dayLabels = ["M","T","W","T","F","S","S"]

        var bars: [WeeklyBarDay] = (0..<7).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart

            let sessMins = sessions
                .filter { cal.isDate($0.startTime, inSameDayAs: day) }
                .reduce(0) { $0 + $1.computedDuration }

            let pomMins = pomodoros
                .filter { cal.isDate($0.recordedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.totalWorkMinutes }

            return WeeklyBarDay(label: dayLabels[offset], date: day, minutes: sessMins + pomMins)
        }
        let maxMinutes = bars.map { $0.minutes }.max() ?? 0
        for i in bars.indices {
            bars[i].fraction = maxMinutes > 0
                ? max(0.05, Double(bars[i].minutes) / Double(maxMinutes))
                : 0.05
        }

        return bars
    }

    // TodayPlanView

    func markSessionComplete(_ session: StudySession) async {
        guard let idx = todaySessions.firstIndex(where: { $0.id == session.id }) else { return }
        todaySessions[idx].isCompleted = true
        var updated = todaySessions[idx]
        updated.isCompleted = true
        try? await FirestoreService.shared.saveSesion(updated)
    }

    func toggleTaskComplete(_ task: StudyTask) async {
        guard let idx = todayTasks.firstIndex(where: { $0.id == task.id }) else { return }
        todayTasks[idx].isCompleted.toggle()
        let updated = todayTasks[idx]
        try? await FirestoreService.shared.saveTask(updated)
        pendingTasks = (pendingTasks + (updated.isCompleted ? -1 : 1)).clamped(to: 0...Int.max)
        overdueTasks = todayTasks.filter { $0.isOverdue }
    }

    private func pushWidgetSnapshot(sessions: [StudySession], tasks: [StudyTask]) {
        let now  = Date()
        let next = sessions
            .filter { !$0.isCompleted && $0.startTime > now }
            .sorted { $0.startTime < $1.startTime }
            .first
        let pendingCount = tasks.filter { !$0.isCompleted && $0.dueDate > now }.count

        let snapshot = WidgetSnapshot(
            nextSessionSubject: next?.subject,
            nextSessionStart:   next?.startTime,
            nextSessionEnd:     next?.endTime,
            pendingTaskCount:   pendingCount,
            todayStudyMinutes:  todayMinutes,
            streakDays:         streakDays
        )
        WidgetDataStore.write(snapshot: snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
