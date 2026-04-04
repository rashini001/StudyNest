import Foundation
import FirebaseAuth
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var displayName: String     = "Student"
    @Published var streakDays: Int         = 0
    @Published var todayMinutes: Int       = 0
    @Published var pendingTasks: Int       = 0
    @Published var weeklyHours: Int        = 0
    @Published var overdueTasks: [StudyTask] = []

    init() { }

    var timeOfDay: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Morning" }
        else if h < 17 { return "Afternoon" }
        else { return "Evening" }
    }

    func load() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        displayName = Auth.auth().currentUser?.displayName ?? "Student"

        let sessions  = (try? await FirestoreService.shared.fetchSessions(for: uid))          ?? []
        let tasks     = (try? await FirestoreService.shared.fetchTasks(for: uid))             ?? []
        let pomodoros = (try? await FirestoreService.shared.fetchPomodoroRecords(for: uid))   ?? []

        let cal = Calendar.current

        // Today's study minutes (sessions + pomodoro)
        todayMinutes = sessions
            .filter  { cal.isDateInToday($0.startTime) }
            .reduce(0) { $0 + $1.computedDuration }
        todayMinutes += pomodoros
            .filter  { cal.isDateInToday($0.recordedAt) }
            .reduce(0) { $0 + $1.totalWorkMinutes }

        // Tasks
        pendingTasks = tasks.filter { !$0.isCompleted }.count
        overdueTasks = tasks.filter {  $0.isOverdue   }

        // Weekly hours
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        weeklyHours = sessions
            .filter  { $0.startTime > weekAgo }
            .reduce(0) { $0 + $1.computedDuration } / 60

        // Streak
        var streak    = 0
        var checkDate = Date()
        while sessions.contains(where: { cal.isDate($0.startTime, inSameDayAs: checkDate) }) {
            streak   += 1
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        streakDays = streak
    }
}
