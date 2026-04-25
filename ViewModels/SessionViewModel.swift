import Foundation
import Combine
import EventKit
import FirebaseFirestore
import FirebaseAuth
import WidgetKit

final class SessionViewModel: ObservableObject {

    @Published var sessions: [StudySession] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    @Published var successMessage = ""

    private let sync       = SyncService.shared
    private let eventStore = EKEventStore()
    private var userId: String { Auth.auth().currentUser?.uid ?? "" }
    private var cancellables = Set<AnyCancellable>()

    init() {
        sync.$isSyncing
            .filter { !$0 }
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadFromCoreData() }
            .store(in: &cancellables)
    }

    var completedSessions: [StudySession] { sessions.filter { $0.isCompleted } }
    var upcomingSessions: [StudySession] {
        sessions.filter { !$0.isCompleted && $0.startTime > Date() }
    }
    var inProgressSessions: [StudySession] {
        sessions.filter { !$0.isCompleted && $0.startTime <= Date() && $0.endTime > Date() }
    }
    var totalMinutesThisWeek: Int {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return completedSessions
            .filter { $0.startTime >= startOfWeek }
            .reduce(0) { $0 + $1.computedDuration }
    }

    func loadSessions() async {
        guard !userId.isEmpty else { return }

        await MainActor.run {
            isLoading = true
            loadFromCoreData()
        }

        if sync.isOnline { await sync.sync() }

        await MainActor.run { isLoading = false }
    }

    private func loadFromCoreData() {
        let raw = sync.fetchSessionsLocally(for: userId)
        var seen = Set<String>()
        sessions = raw.filter { session in
            guard let id = session.id else { return true }
            return seen.insert(id).inserted
        }
    }

    // Add Session

    func addSession(subject: String, startTime: Date, endTime: Date, notes: String) async {
        guard !subject.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run { errorMessage = "Please enter a subject." }
            return
        }
        guard endTime > startTime else {
            await MainActor.run { errorMessage = "End time must be after start time." }
            return
        }

        await MainActor.run { isLoading = true; errorMessage = nil }

        let calendarEventId = await addToCalendar(
            subject: subject, startTime: startTime, endTime: endTime, notes: notes
        )

        var session = StudySession(
            id:              UUID().uuidString,
            userId:          userId,
            subject:         subject,
            startTime:       startTime,
            endTime:         endTime,
            notes:           notes,
            isCompleted:     false,
            calendarEventId: calendarEventId,
            createdAt:       Date()
        )

        let notifIds = NotificationService.shared.scheduleSessionNotifications(for: session)
        session.notificationIds = notifIds

        if sync.isOnline {
            do {
                let ref = try await Firestore.firestore()
                    .collection("sessions")
                    .addDocument(data: session.toFirestoreData())
                session.id = ref.documentID
            } catch {
                print("Firestore write failed (will retry): \(error)")
            }
        }

        sync.saveSessionLocally(session)

        await MainActor.run {
            loadFromCoreData()
            successMessage = sync.isOnline
                ? "Session saved & synced to calendar ✓"
                : "Session saved offline — will sync when online"
            showSuccess = true
            isLoading   = false
        }

        refreshWidget()
    }

    // Mark Complete

    func markComplete(_ session: StudySession) async {
        var updated = session
        updated.isCompleted = true
        sync.saveSessionLocally(updated)

        if sync.isOnline, let id = session.id {
            try? await Firestore.firestore()
                .collection("sessions").document(id)
                .updateData(["isCompleted": true])
        }

        await MainActor.run { loadFromCoreData() }
        refreshWidget()
    }

    // Delete Session

    func deleteSession(_ session: StudySession) async {
        if let calId = session.calendarEventId { removeFromCalendar(eventId: calId) }
        if let id = session.id {
            NotificationService.shared.cancelSessionNotifications(sessionId: id)
        }

        if let id = session.id {
            sync.deleteSessionLocally(id: id)

            if sync.isOnline {
                try? await Firestore.firestore().collection("sessions").document(id).delete()
            }
        }

        await MainActor.run { loadFromCoreData() }
        refreshWidget()
    }

    private func refreshWidget() { WidgetCenter.shared.reloadAllTimelines() }

    // EventKit

    private func addToCalendar(
        subject: String, startTime: Date, endTime: Date, notes: String
    ) async -> String? {
        let granted = await withCheckedContinuation { cont in
            if #available(iOS 17, *) {
                eventStore.requestFullAccessToEvents { ok, _ in cont.resume(returning: ok) }
            } else {
                eventStore.requestAccess(to: .event) { ok, _ in cont.resume(returning: ok) }
            }
        }
        guard granted else { return nil }

        let event       = EKEvent(eventStore: eventStore)
        event.title     = "📚 Study: \(subject)"
        event.startDate = startTime
        event.endDate   = endTime
        event.notes     = notes.isEmpty ? nil : notes
        event.calendar  = eventStore.defaultCalendarForNewEvents
        event.addAlarm(EKAlarm(relativeOffset: -86_400))
        event.addAlarm(EKAlarm(relativeOffset: -3_600))

        try? eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    private func removeFromCalendar(eventId: String) {
        guard let event = eventStore.event(withIdentifier: eventId) else { return }
        try? eventStore.remove(event, span: .thisEvent)
    }
}
