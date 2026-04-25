import Foundation
import Combine
import EventKit
import WidgetKit

@MainActor
final class TaskViewModel: ObservableObject {

    @Published var tasks: [StudyTask]            = []
    @Published var filterPriority: TaskPriority? = nil
    @Published var isLoading: Bool               = false

    private let sync       = SyncService.shared
    private let eventStore = EKEventStore()
    private var userId: String { AuthService.shared.currentUserId ?? "" }
    private var cancellables = Set<AnyCancellable>()

    init() {
        sync.$isSyncing
            .filter { !$0 }
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadFromCoreData() }
            .store(in: &cancellables)
    }

    var filteredTasks: [StudyTask] {
        guard let p = filterPriority else { return tasks }
        return tasks.filter { $0.priority == p }
    }

    var overdueTasks:   [StudyTask] { tasks.filter { $0.isOverdue }    }
    var pendingTasks:   [StudyTask] { tasks.filter { !$0.isCompleted } }
    var completedTasks: [StudyTask] { tasks.filter { $0.isCompleted }  }

    func loadTasks() async {
        guard !userId.isEmpty else { return }
        isLoading = true
        loadFromCoreData()
        if sync.isOnline { await sync.sync() }
        isLoading = false
    }

    private func loadFromCoreData() {
        tasks = sync.fetchTasksLocally(for: userId)
    }

    //Add Task

    func addTask(title: String, subject: String,
                 dueDate: Date, priority: TaskPriority) async {
        guard !userId.isEmpty else { return }

        var task = StudyTask(
            id:          UUID().uuidString,
            userId:      userId,
            title:       title,
            subject:     subject,
            dueDate:     dueDate,
            priority:    priority,
            isCompleted: false,
            createdAt:   Date()
        )
        task.notificationId = NotificationService.shared.scheduleTaskNotification(for: task)

        if priority == .high {
            task.calendarEventId = await addToCalendar(task: task)
        }

        sync.saveTaskLocally(task)

        if sync.isOnline {
            do {
                try await FirestoreService.shared.saveTask(task)
            } catch {
                print("Firestore task write failed (will retry on reconnect): \(error)")
            }
        }

        loadFromCoreData()
        refreshWidget()
    }

    func toggleCompletion(_ task: StudyTask) async {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isCompleted.toggle()
        if tasks[idx].isCompleted, let id = task.id {
            NotificationService.shared.cancelTaskNotification(taskId: id)
        }

        sync.saveTaskLocally(tasks[idx])

        if sync.isOnline {
            try? await FirestoreService.shared.saveTask(tasks[idx])
        }

        refreshWidget()
    }

    //Delete Task

    func deleteTask(_ task: StudyTask) async {
        guard let id = task.id else { return }
        NotificationService.shared.cancelTaskNotification(taskId: id)

        sync.deleteTaskLocally(id: id)

        loadFromCoreData()
        refreshWidget()
    }

    private func refreshWidget() { WidgetCenter.shared.reloadAllTimelines() }

    //Calendar

    private func addToCalendar(task: StudyTask) async -> String? {
        let granted = await withCheckedContinuation { cont in
            eventStore.requestFullAccessToEvents { ok, _ in cont.resume(returning: ok) }
        }
        guard granted else { return nil }

        let event       = EKEvent(eventStore: eventStore)
        event.title     = task.title
        event.startDate = task.dueDate
        event.endDate   = task.dueDate.addingTimeInterval(3600)
        event.calendar  = eventStore.defaultCalendarForNewEvents
        event.addAlarm(EKAlarm(relativeOffset: -3600))

        try? eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }
}
