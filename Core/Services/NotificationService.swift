import UserNotifications
import Foundation

final class NotificationService {
    static let shared = NotificationService()

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            print("Notifications granted: \(granted)")
        }
    }

    @discardableResult
    func scheduleSessionNotification(for session: StudySession) -> String {
        let id = UUID().uuidString
        schedule(id: id, title: "Study Session Starting",
                 body: "\(session.subject) session starts in 1 hour",
                 date: session.startTime.addingTimeInterval(-3600))
        return id
    }

    @discardableResult
    func scheduleTaskNotification(for task: StudyTask) -> String {
        let id = UUID().uuidString
        schedule(id: id, title: "Task Due Soon",
                 body: "\(task.title) is due in 1 hour",
                 date: task.dueDate.addingTimeInterval(-3600))
        return id
    }

    func schedulePomodoroEnd(phase: String) {
        schedule(id: UUID().uuidString,
                 title: "Pomodoro Phase Complete",
                 body: phase == "work" ? "Time for a break!" : "Back to work!",
                 date: Date().addingTimeInterval(1))
    }

    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private func schedule(id: String, title: String, body: String, date: Date) {
        guard date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

