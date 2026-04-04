//
//  SessionViewModel.swift
//  StudyNest
//

import Foundation
import Combine
import EventKit
import FirebaseFirestore

// NOTE: @MainActor is NOT on the class — it conflicts with ObservableObject
// synthesis in some Xcode versions. Individual async methods publish UI
// updates via MainActor.run, and since SwiftUI's .task / Task {} contexts
// already run on the main actor, @Published updates land on the main thread.
final class SessionViewModel: ObservableObject {

    // MARK: - Published State
    @Published var sessions: [StudySession] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    @Published var successMessage = ""

    // MARK: - Private
    private let firestore = FirestoreService.shared
    private let eventStore = EKEventStore()
    private var userId: String { AuthService.shared.currentUserId ?? "" }

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
    func loadSessions() async {
        let uid = userId
        guard !uid.isEmpty else { return }   // not logged in yet — skip silently
        await MainActor.run { isLoading = true }
        let fetched = (try? await firestore.fetchSessions(for: uid)) ?? []
        await MainActor.run {
            sessions = fetched
            isLoading = false
        }
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

        // 2. Save to Firestore
        let session = StudySession(
            userId: userId,
            subject: subject,
            startTime: startTime,
            endTime: endTime,
            notes: notes,
            isCompleted: false,
            calendarEventId: calendarEventId,
            createdAt: Date()
        )

        do {
            try await firestore.saveSesion(session)
            await loadSessions()
            await MainActor.run {
                successMessage = "Session added to calendar ✓"
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not save session: \(error.localizedDescription)"
            }
        }

        await MainActor.run { isLoading = false }
    }

    // MARK: - Mark Complete
    func markComplete(_ session: StudySession) async {
        guard let idx = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        await MainActor.run { sessions[idx].isCompleted = true }
        let updated = sessions[idx]
        try? await firestore.saveSesion(updated)
    }

    // MARK: - Delete Session
    func deleteSession(_ session: StudySession) async {
        guard let id = session.id else { return }
        if let calId = session.calendarEventId { removeFromCalendar(eventId: calId) }
        try? await firestore.deleteSession(id: id)
        await MainActor.run { sessions.removeAll { $0.id == id } }
    }

    // MARK: - EventKit

    private func addToCalendar(subject: String, startTime: Date, endTime: Date, notes: String) async -> String? {
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
        event.addAlarm(EKAlarm(relativeOffset: -86_400)) // 24 hr
        event.addAlarm(EKAlarm(relativeOffset: -3_600))  // 1 hr

        try? eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    private func removeFromCalendar(eventId: String) {
        guard let event = eventStore.event(withIdentifier: eventId) else { return }
        try? eventStore.remove(event, span: .thisEvent)
    }
}
