//
//  SessionViewModel.swift
//  StudyNest
//
//  Offline-first: reads Core Data immediately, syncs Firestore in background.
//

import Foundation
import Combine
import EventKit
import FirebaseFirestore
import FirebaseAuth

final class SessionViewModel: ObservableObject {

    // MARK: - Published
    @Published var sessions: [StudySession] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    @Published var successMessage = ""

    // MARK: - Dependencies
    private let sync      = SyncService.shared
    private let eventStore = EKEventStore()
    private var userId: String { Auth.auth().currentUser?.uid ?? "" }
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init() {
        // Whenever SyncService finishes a sync, refresh our local list
        sync.$isSyncing
            .filter { !$0 }           // just finished syncing
            .dropFirst()              // ignore initial false
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadFromCoreData() }
            .store(in: &cancellables)
    }

    // MARK: - Computed
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

    // MARK: - Load
    //
    // Step 1 — instantly load from Core Data (works offline, zero latency)
    // Step 2 — if online, trigger a Firestore sync in the background;
    //           the Combine sink above will reload once sync finishes.
    func loadSessions() async {
        guard !userId.isEmpty else { return }

        await MainActor.run {
            isLoading = true
            loadFromCoreData()        // show cached data immediately
        }

        if sync.isOnline {
            await sync.sync()         // push pending + pull fresh data
        }

        await MainActor.run { isLoading = false }
    }

    // Read Core Data and publish to the view
    private func loadFromCoreData() {
        sessions = sync.fetchSessionsLocally(for: userId)
    }

    // MARK: - Add Session
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

        // 1. EventKit — 24hr + 1hr alerts
        let calendarEventId = await addToCalendar(
            subject: subject, startTime: startTime, endTime: endTime, notes: notes
        )

        // 2. Build model with a local UUID (Firestore doc id if online)
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

        // 3. Save to Core Data immediately (offline-safe)
        sync.saveSessionLocally(session)

        // 4. If online push to Firestore right now; otherwise it will
        //    sync automatically when connectivity returns.
        if sync.isOnline {
            do {
                let ref = try await Firestore.firestore()
                    .collection("sessions")
                    .addDocument(data: session.toFirestoreData())
                // Update Core Data with the real Firestore ID
                session.id = ref.documentID
                sync.saveSessionLocally(session)
            } catch {
                // Local copy already saved — will retry on reconnect
                print("Firestore write failed (will retry): \(error)")
            }
        }

        await MainActor.run {
            loadFromCoreData()
            successMessage = sync.isOnline
                ? "Session saved & synced to calendar ✓"
                : "Session saved offline — will sync when online"
            showSuccess = true
            isLoading = false
        }
    }

    // MARK: - Mark Complete
    func markComplete(_ session: StudySession) async {
        var updated = session
        updated.isCompleted = true
        sync.saveSessionLocally(updated)      // Core Data

        if sync.isOnline, let id = session.id {
            try? await Firestore.firestore()
                .collection("sessions").document(id)
                .updateData(["isCompleted": true])
        }

        await MainActor.run { loadFromCoreData() }
    }

    // MARK: - Delete Session
    func deleteSession(_ session: StudySession) async {
        if let calId = session.calendarEventId { removeFromCalendar(eventId: calId) }

        if let id = session.id {
            sync.deleteSessionLocally(id: id)  // Core Data (marks pendingDelete if offline)

            if sync.isOnline {
                try? await Firestore.firestore().collection("sessions").document(id).delete()
            }
        }

        await MainActor.run { loadFromCoreData() }
    }

    // MARK: - EventKit

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

        let event = EKEvent(eventStore: eventStore)
        event.title     = "📚 Study: \(subject)"
        event.startDate = startTime
        event.endDate   = endTime
        event.notes     = notes.isEmpty ? nil : notes
        event.calendar  = eventStore.defaultCalendarForNewEvents
        event.addAlarm(EKAlarm(relativeOffset: -86_400))  // 24 hr
        event.addAlarm(EKAlarm(relativeOffset: -3_600))   // 1 hr

        try? eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    private func removeFromCalendar(eventId: String) {
        guard let event = eventStore.event(withIdentifier: eventId) else { return }
        try? eventStore.remove(event, span: .thisEvent)
    }
}
