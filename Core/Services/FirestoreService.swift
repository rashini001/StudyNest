import Foundation
import FirebaseFirestore

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    // MARK: - Sessions

    func saveSesion(_ session: StudySession) async throws {
        if let id = session.id {
            try await db.collection("sessions").document(id).setData(session.toFirestoreData())
        } else {
            _ = try await db.collection("sessions").addDocument(data: session.toFirestoreData())
        }
    }

    func fetchSessions(for userId: String) async throws -> [StudySession] {
        let snapshot = try await db.collection("sessions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "startTime", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { StudySession(document: $0) }
    }

    func deleteSession(id: String) async throws {
        try await db.collection("sessions").document(id).delete()
    }

    // MARK: - Study Spots

    func saveSpot(_ spot: StudySpot) async throws {
        if let id = spot.id {
            try await db.collection("spots").document(id).setData(spot.toFirestoreData())
        } else {
            _ = try await db.collection("spots").addDocument(data: spot.toFirestoreData())
        }
    }

    func fetchSpots(for userId: String) async throws -> [StudySpot] {
        let snapshot = try await db.collection("spots")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        return snapshot.documents.compactMap { StudySpot(document: $0) }
    }

    func deleteSpot(id: String) async throws {
        try await db.collection("spots").document(id).delete()
    }

    // MARK: - PDF Notes

    func saveNote(_ note: PDFNote) async throws {
        if let id = note.id {
            try await db.collection("notes").document(id).setData(note.toFirestoreData())
        } else {
            _ = try await db.collection("notes").addDocument(data: note.toFirestoreData())
        }
    }

    func fetchNotes(for userId: String) async throws -> [PDFNote] {
        let snapshot = try await db.collection("notes")
            .whereField("userId", isEqualTo: userId)
            .order(by: "uploadedAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { PDFNote(document: $0) }
    }

    func deleteNote(id: String) async throws {
        try await db.collection("notes").document(id).delete()
    }

    // MARK: - Flashcard Decks

    func saveFlashcardDeck(_ deck: FlashcardDeck) async throws -> String {
        if let id = deck.id {
            try await db.collection("decks").document(id).setData(deck.toFirestoreData())
            return id
        } else {
            let ref = try await db.collection("decks").addDocument(data: deck.toFirestoreData())
            return ref.documentID
        }
    }

    func fetchDecks(for userId: String) async throws -> [FlashcardDeck] {
        let snapshot = try await db.collection("decks")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { FlashcardDeck(document: $0) }
    }

    func deleteDeck(id: String) async throws {
        // Delete all subcollection cards first
        let cards = try await db.collection("decks").document(id)
            .collection("cards").getDocuments()
        for card in cards.documents {
            try await card.reference.delete()
        }
        try await db.collection("decks").document(id).delete()
    }

    // MARK: - Flashcards

    func saveCard(_ card: Flashcard, toDeck deckId: String) async throws {
        if let id = card.id {
            try await db.collection("decks").document(deckId)
                .collection("cards").document(id).setData(card.toFirestoreData())
        } else {
            _ = try await db.collection("decks").document(deckId)
                .collection("cards").addDocument(data: card.toFirestoreData())
        }
    }

    func fetchCards(for deckId: String) async throws -> [Flashcard] {
        let snapshot = try await db.collection("decks")
            .document(deckId).collection("cards").getDocuments()
        return snapshot.documents.compactMap { Flashcard(document: $0) }
    }

    func deleteCard(id: String, fromDeck deckId: String) async throws {
        try await db.collection("decks").document(deckId)
            .collection("cards").document(id).delete()
    }

    /// Atomic accuracy update — only writes changed fields
    func updateCardAccuracy(_ card: Flashcard, toDeck deckId: String) async throws {
        guard let id = card.id else { return }
        try await db.collection("decks").document(deckId)
            .collection("cards").document(id).updateData([
                "timesAttempted": card.timesAttempted,
                "timesCorrect":   card.timesCorrect
            ])
    }

    // MARK: - Tasks

    func saveTask(_ task: StudyTask) async throws {
        if let id = task.id {
            try await db.collection("tasks").document(id).setData(task.toFirestoreData())
        } else {
            _ = try await db.collection("tasks").addDocument(data: task.toFirestoreData())
        }
    }

    func fetchTasks(for userId: String) async throws -> [StudyTask] {
        let snapshot = try await db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .order(by: "dueDate")
            .getDocuments()
        return snapshot.documents.compactMap { StudyTask(document: $0) }
    }

    // MARK: - Pomodoro

    func savePomodoroRecord(_ record: PomodoroRecord) async throws {
        _ = try await db.collection("pomodoro").addDocument(data: record.toFirestoreData())
    }

    func fetchPomodoroRecords(for userId: String) async throws -> [PomodoroRecord] {
        let snapshot = try await db.collection("pomodoro")
            .whereField("userId", isEqualTo: userId)
            .order(by: "recordedAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        return snapshot.documents.compactMap { PomodoroRecord(document: $0) }
    }
}
