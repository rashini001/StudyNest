import Foundation
import Combine
import EventKit

@MainActor
final class TaskViewModel: ObservableObject {
    @Published var tasks: [StudyTask]          = []
    @Published var filterPriority: TaskPriority? = nil
    @Published var isLoading: Bool             = false

    private let eventStore = EKEventStore()

    init() { }

    // MARK: - Computed

    var filteredTasks: [StudyTask] {
        guard let p = filterPriority else { return tasks }
        return tasks.filter { $0.priority == p }
    }
    var overdueTasks: [StudyTask] { tasks.filter { $0.isOverdue } }

    // MARK: - Load

    func loadTasks() async {
        isLoading = true
        guard let userId = AuthService.shared.currentUserId else { isLoading = false; return }
        tasks = (try? await FirestoreService.shared.fetchTasks(for: userId)) ?? []
        isLoading = false
    }

    // MARK: - Add

    func addTask(title: String, subject: String,
                 dueDate: Date, priority: TaskPriority) async {
        guard let userId = AuthService.shared.currentUserId else { return }

        var task = StudyTask(
            userId: userId, title: title, subject: subject,
            dueDate: dueDate, priority: priority,
            isCompleted: false, createdAt: Date()
        )
        task.notificationId = NotificationService.shared.scheduleTaskNotification(for: task)

        if priority == .high {
            task.calendarEventId = await addToCalendar(task: task)
        }

        try? await FirestoreService.shared.saveTask(task)
        tasks.append(task)
        tasks.sort { $0.dueDate < $1.dueDate }
    }

    // MARK: - Toggle

    func toggleCompletion(_ task: StudyTask) async {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isCompleted.toggle()
        try? await FirestoreService.shared.saveTask(tasks[idx])
    }

    // MARK: - Calendar

    private func addToCalendar(task: StudyTask) async -> String? {
        let granted = await withCheckedContinuation { cont in
            eventStore.requestFullAccessToEvents { ok, _ in cont.resume(returning: ok) }
        }
        guard granted else { return nil }
        let event        = EKEvent(eventStore: eventStore)
        event.title      = task.title
        event.startDate  = task.dueDate
        event.endDate    = task.dueDate.addingTimeInterval(3600)
        event.calendar   = eventStore.defaultCalendarForNewEvents
        try? eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }
}
