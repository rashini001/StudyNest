import UserNotifications
import Foundation
final class NotificationService: NSObject {

    static let shared = NotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    //  Authorization

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            print("StudyNest notifications granted: \(granted)")
        } catch {
            print("StudyNest notification auth error: \(error.localizedDescription)")
        }
    }

    // Session Reminders

    @discardableResult
    func scheduleSessionNotifications(for session: StudySession) -> [String] {
        let id24 = "session-24hr-\(session.id ?? UUID().uuidString)"
        let id1  = "session-1hr-\(session.id ?? UUID().uuidString)"

        schedule(
            id:    id24,
            title: "📚 Study Session Tomorrow",
            body:  "\(session.subject) starts in 24 hours. Get ready!",
            date:  session.startTime.addingTimeInterval(-86_400)
        )

        schedule(
            id:    id1,
            title: "📚 Study Session Starting Soon",
            body:  "\(session.subject) starts in 1 hour.",
            date:  session.startTime.addingTimeInterval(-3_600)
        )

        return [id24, id1]
    }

    func cancelSessionNotifications(sessionId: String) {
        let ids = ["session-24hr-\(sessionId)", "session-1hr-\(sessionId)"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // Task Deadline Alert

    @discardableResult
    func scheduleTaskNotification(for task: StudyTask) -> String {
        let id = "task-1hr-\(task.id ?? UUID().uuidString)"
        schedule(
            id:    id,
            title: "✅ Task Due Soon",
            body:  "\"\(task.title)\" is due in 1 hour.",
            date:  task.dueDate.addingTimeInterval(-3_600)
        )
        return id
    }

    func cancelTaskNotification(taskId: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["task-1hr-\(taskId)"])
    }

    // Pomodoro Cycle-End

    func schedulePomodoroEnd(completedPhase: String) {
        let isWork = completedPhase.lowercased().contains("work")
        schedule(
            id:    "pomodoro-end-\(UUID().uuidString)",
            title: isWork ? "🎯 Focus Session Complete!" : "☕️ Break Over!",
            body:  isWork ? "Great work! Time for a well-earned break."
                          : "Break's up — back to focusing!",
            date:  Date().addingTimeInterval(1)
        )
    }

    // Generic cancel

    func cancelNotification(id: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }

    // Private scheduler

    private func schedule(id: String, title: String, body: String, date: Date) {
        guard date > Date() else {
            print("StudyNest: skipping notification '\(id)' — date is in the past.")
            return
        }

        let content       = UNMutableNotificationContent()
        content.title     = title
        content.body      = body
        content.sound     = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("StudyNest: failed to schedule '\(id)': \(error.localizedDescription)")
            }
        }
    }
}

// UNUserNotificationCenterDelegate


extension NotificationService: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
