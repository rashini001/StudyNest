//
//  SyncService.swift
//  StudyNest
//
//  Offline-first sync engine.
//
//  Strategy
//  ────────
//  1. Every write goes to Core Data first (instant, no network needed).
//     `needsSync = true` marks the record as pending upload.
//  2. NWPathMonitor watches connectivity.
//  3. On reconnect → pushSync() flushes all pending Core Data rows to
//     Firestore, then pullSync() fetches fresh Firestore data and
//     updates Core Data (Firestore wins for any conflicts).
//  4. Views always read from Core Data, so they work 100% offline.
//

import Foundation
import Combine
import Network
import CoreData
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class SyncService: ObservableObject {

    // MARK: - Singleton
    static let shared = SyncService()

    // MARK: - Published
    @Published private(set) var isOnline: Bool = false
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncDate: Date? = nil

    // MARK: - Private
    private let monitor   = NWPathMonitor()
    private let monitorQ  = DispatchQueue(label: "com.studynest.network")
    private let db        = Firestore.firestore()
    private let ctx       = PersistenceController.shared.viewContext
    private var userId: String { Auth.auth().currentUser?.uid ?? "" }

    private init() {
        startMonitoring()
    }

    // MARK: - Network Monitor

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = online
                // Came back online → sync immediately
                if online && wasOffline {
                    await self.sync()
                }
            }
        }
        monitor.start(queue: monitorQ)
    }

    // MARK: - Full Sync (push then pull)

    func sync() async {
        guard !userId.isEmpty, isOnline else { return }
        isSyncing = true
        await pushPendingSessions()
        await pushPendingSpots()
        await pushPendingNotes()
        await pullSessions()
        await pullSpots()
        await pullNotes()
        lastSyncDate = Date()
        isSyncing = false
    }

    // MARK: - PUSH — Sessions

    private func pushPendingSessions() async {
        let req: NSFetchRequest<CDSession> = CDSession.fetchRequest()
        req.predicate = NSPredicate(format: "needsSync == YES AND userId == %@", userId)
        guard let pending = try? ctx.fetch(req) else { return }

        for cd in pending {
            let data = cd.toModel().toFirestoreData()
            let docId = cd.id ?? UUID().uuidString
            cd.id = docId

            if cd.pendingDelete {
                try? await db.collection("sessions").document(docId).delete()
                ctx.delete(cd)
            } else {
                try? await db.collection("sessions").document(docId).setData(data)
                cd.needsSync = false
            }
        }
        PersistenceController.shared.save()
    }

    // MARK: - PUSH — Spots

    private func pushPendingSpots() async {
        let req: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
        req.predicate = NSPredicate(format: "needsSync == YES AND userId == %@", userId)
        guard let pending = try? ctx.fetch(req) else { return }

        for cd in pending {
            let docId = cd.id ?? UUID().uuidString
            cd.id = docId
            if cd.pendingDelete {
                try? await db.collection("spots").document(docId).delete()
                ctx.delete(cd)
            } else {
                try? await db.collection("spots").document(docId).setData(cd.toModel().toFirestoreData())
                cd.needsSync = false
            }
        }
        PersistenceController.shared.save()
    }

    // MARK: - PUSH — Notes

    private func pushPendingNotes() async {
        let req: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        req.predicate = NSPredicate(format: "needsSync == YES AND userId == %@", userId)
        guard let pending = try? ctx.fetch(req) else { return }

        for cd in pending {
            let docId = cd.id ?? UUID().uuidString
            cd.id = docId
            if cd.pendingDelete {
                try? await db.collection("notes").document(docId).delete()
                ctx.delete(cd)
            } else {
                try? await db.collection("notes").document(docId).setData(cd.toModel().toFirestoreData())
                cd.needsSync = false
            }
        }
        PersistenceController.shared.save()
    }

    // MARK: - PULL — Sessions

    private func pullSessions() async {
        guard let snap = try? await db.collection("sessions")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        else { return }

        let remote = snap.documents.compactMap { StudySession(document: $0) }

        // Upsert into Core Data (Firestore wins)
        for s in remote {
            let req: NSFetchRequest<CDSession> = CDSession.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", s.id ?? "")
            let existing = (try? ctx.fetch(req))?.first ?? CDSession(context: ctx)
            existing.populate(from: s)
            existing.needsSync    = false
            existing.pendingDelete = false
        }

        // Remove local rows that no longer exist in Firestore
        let remoteIds = Set(remote.compactMap { $0.id })
        let allReq: NSFetchRequest<CDSession> = CDSession.fetchRequest()
        allReq.predicate = NSPredicate(format: "userId == %@", userId)
        if let all = try? ctx.fetch(allReq) {
            for cd in all where !remoteIds.contains(cd.id ?? "") && !cd.needsSync {
                ctx.delete(cd)
            }
        }

        PersistenceController.shared.save()
    }

    // MARK: - PULL — Spots

    private func pullSpots() async {
        guard let snap = try? await db.collection("spots")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        else { return }

        let remote = snap.documents.compactMap { StudySpot(document: $0) }
        let remoteIds = Set(remote.compactMap { $0.id })

        for s in remote {
            let req: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", s.id ?? "")
            let existing = (try? ctx.fetch(req))?.first ?? CDSpot(context: ctx)
            existing.populate(from: s)
            existing.needsSync     = false
            existing.pendingDelete = false
        }

        let allReq: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
        allReq.predicate = NSPredicate(format: "userId == %@", userId)
        if let all = try? ctx.fetch(allReq) {
            for cd in all where !remoteIds.contains(cd.id ?? "") && !cd.needsSync {
                ctx.delete(cd)
            }
        }

        PersistenceController.shared.save()
    }

    // MARK: - PULL — Notes

    private func pullNotes() async {
        guard let snap = try? await db.collection("notes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        else { return }

        let remote = snap.documents.compactMap { PDFNote(document: $0) }
        let remoteIds = Set(remote.compactMap { $0.id })

        for n in remote {
            let req: NSFetchRequest<CDNote> = CDNote.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", n.id ?? "")
            let existing = (try? ctx.fetch(req))?.first ?? CDNote(context: ctx)
            existing.populate(from: n)
            existing.needsSync     = false
            existing.pendingDelete = false
        }

        let allReq: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        allReq.predicate = NSPredicate(format: "userId == %@", userId)
        if let all = try? ctx.fetch(allReq) {
            for cd in all where !remoteIds.contains(cd.id ?? "") && !cd.needsSync {
                ctx.delete(cd)
            }
        }

        PersistenceController.shared.save()
    }

    // MARK: - Local CRUD helpers used by ViewModels

    // ── Sessions ──────────────────────────────────────────────────

    func saveSessionLocally(_ session: StudySession) {
        let req: NSFetchRequest<CDSession> = CDSession.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", session.id ?? "___none___")
        let cd = (try? ctx.fetch(req))?.first ?? CDSession(context: ctx)
        cd.populate(from: session)
        cd.needsSync     = true
        cd.pendingDelete = false
        PersistenceController.shared.save()
    }

    func deleteSessionLocally(id: String) {
        let req: NSFetchRequest<CDSession> = CDSession.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id)
        guard let cd = (try? ctx.fetch(req))?.first else { return }
        if isOnline {
            ctx.delete(cd)
        } else {
            cd.pendingDelete = true
            cd.needsSync     = true
        }
        PersistenceController.shared.save()
    }

    func fetchSessionsLocally(for uid: String) -> [StudySession] {
        let req: NSFetchRequest<CDSession> = CDSession.fetchRequest()
        req.predicate = NSPredicate(format: "userId == %@ AND pendingDelete == NO", uid)
        req.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        return (try? ctx.fetch(req))?.map { $0.toModel() } ?? []
    }

    // ── Spots ─────────────────────────────────────────────────────

    func saveSpotLocally(_ spot: StudySpot) {
        let req: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", spot.id ?? "___none___")
        let cd = (try? ctx.fetch(req))?.first ?? CDSpot(context: ctx)
        cd.populate(from: spot)
        cd.needsSync     = true
        cd.pendingDelete = false
        PersistenceController.shared.save()
    }

    func deleteSpotLocally(id: String) {
        let req: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id)
        guard let cd = (try? ctx.fetch(req))?.first else { return }
        if isOnline { ctx.delete(cd) } else { cd.pendingDelete = true; cd.needsSync = true }
        PersistenceController.shared.save()
    }

    func fetchSpotsLocally(for uid: String) -> [StudySpot] {
        let req: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
        req.predicate = NSPredicate(format: "userId == %@ AND pendingDelete == NO", uid)
        req.sortDescriptors = [NSSortDescriptor(key: "savedAt", ascending: false)]
        return (try? ctx.fetch(req))?.map { $0.toModel() } ?? []
    }

    // ── Notes ─────────────────────────────────────────────────────

    func saveNoteLocally(_ note: PDFNote) {
        let req: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", note.id ?? "___none___")
        let cd = (try? ctx.fetch(req))?.first ?? CDNote(context: ctx)
        cd.populate(from: note)
        cd.needsSync     = true
        cd.pendingDelete = false
        PersistenceController.shared.save()
    }

    func deleteNoteLocally(id: String) {
        let req: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id)
        guard let cd = (try? ctx.fetch(req))?.first else { return }
        if isOnline { ctx.delete(cd) } else { cd.pendingDelete = true; cd.needsSync = true }
        PersistenceController.shared.save()
    }

    func fetchNotesLocally(for uid: String) -> [PDFNote] {
        let req: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        req.predicate = NSPredicate(format: "userId == %@ AND pendingDelete == NO", uid)
        req.sortDescriptors = [NSSortDescriptor(key: "uploadedAt", ascending: false)]
        return (try? ctx.fetch(req))?.map { $0.toModel() } ?? []
    }
}
