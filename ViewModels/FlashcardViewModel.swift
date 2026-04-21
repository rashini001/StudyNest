import Foundation
import Combine

struct ScanPair: Identifiable {
    let id = UUID()
    var question: String
    var answer: String
    var accepted: Bool = true
}

@MainActor
final class FlashcardViewModel: ObservableObject {

    @Published var decks: [FlashcardDeck]     = []
    @Published var currentCards: [Flashcard]  = []
    @Published var reviewIndex: Int           = 0
    @Published var showingAnswer: Bool        = false
    @Published var correctCount: Int          = 0
    @Published var retryCount: Int            = 0
    @Published var isLoading: Bool            = false
    @Published var isSaving: Bool             = false
    @Published var errorMessage: String?      = nil

    @Published var scanPairs: [ScanPair]      = []

    init() { }


    var currentCard: Flashcard? { currentCards[safe: reviewIndex] }
    var reviewComplete: Bool    { reviewIndex >= currentCards.count && !currentCards.isEmpty }

    //Deck operations

    func loadDecks() async {
        isLoading = true
        defer { isLoading = false }
        guard let userId = AuthService.shared.currentUserId else { return }
        do {
            decks = try await FirestoreService.shared.fetchDecks(for: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createDeck(title: String, subject: String) async {
        guard let userId = AuthService.shared.currentUserId else { return }
        let deck = FlashcardDeck(
            userId: userId, title: title,
            subject: subject, cardCount: 0, createdAt: Date()
        )
        do {
            let id  = try await FirestoreService.shared.saveFlashcardDeck(deck)
            var saved = deck; saved.id = id
            decks.insert(saved, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteDeck(_ deck: FlashcardDeck) async {
        guard let id = deck.id else { return }
        do {
            try await FirestoreService.shared.deleteDeck(id: id)
            decks.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Card operations

    func loadCards(for deck: FlashcardDeck) async {
        guard let id = deck.id else { return }
        isLoading     = true
        defer { isLoading = false }
        currentCards  = (try? await FirestoreService.shared.fetchCards(for: id)) ?? []
        reviewIndex   = 0
        correctCount  = 0
        retryCount    = 0
        showingAnswer = false
    }

    func addCard(question: String, answer: String, toDeck deck: FlashcardDeck) async {
        guard let deckId = deck.id else { return }
        isSaving = true
        defer { isSaving = false }
        let card = Flashcard(
            deckId: deckId, question: question,
            answer: answer, timesAttempted: 0, timesCorrect: 0
        )
        do {
            try await FirestoreService.shared.saveCard(card, toDeck: deckId)
            
            var updated        = deck
            updated.cardCount += 1
            _ = try? await FirestoreService.shared.saveFlashcardDeck(updated)
            if let idx = decks.firstIndex(where: { $0.id == deckId }) {
                decks[idx].cardCount += 1
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func buildScanPairs(from lines: [String]) {
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                           .filter { !$0.isEmpty }
        var pairs: [ScanPair] = []
        var i = 0
        while i + 1 < cleaned.count {
            pairs.append(ScanPair(question: cleaned[i], answer: cleaned[i + 1]))
            i += 2
        }
        
        if cleaned.count % 2 == 1, let last = cleaned.last {
            pairs.append(ScanPair(question: last, answer: ""))
        }
        scanPairs = pairs
    }

    func swapPair(at index: Int) {
        guard scanPairs.indices.contains(index) else { return }
        let old = scanPairs[index]
        scanPairs[index] = ScanPair(question: old.answer, answer: old.question)
    }

    func toggleAccepted(at index: Int) {
        guard scanPairs.indices.contains(index) else { return }
        scanPairs[index].accepted.toggle()
    }

    func updatePairQuestion(_ text: String, at index: Int) {
        guard scanPairs.indices.contains(index) else { return }
        scanPairs[index].question = text
    }

    func updatePairAnswer(_ text: String, at index: Int) {
        guard scanPairs.indices.contains(index) else { return }
        scanPairs[index].answer = text
    }

    func saveAcceptedScanPairs(toDeck deck: FlashcardDeck) async {
        guard let deckId = deck.id else { return }
        isSaving = true
        defer { isSaving = false }
        let accepted = scanPairs.filter { $0.accepted && !$0.question.isEmpty }
        for pair in accepted {
            let card = Flashcard(
                deckId: deckId, question: pair.question,
                answer: pair.answer, timesAttempted: 0, timesCorrect: 0
            )
            try? await FirestoreService.shared.saveCard(card, toDeck: deckId)
        }
       
        var updated        = deck
        updated.cardCount += accepted.count
        _ = try? await FirestoreService.shared.saveFlashcardDeck(updated)
        if let idx = decks.firstIndex(where: { $0.id == deckId }) {
            decks[idx].cardCount += accepted.count
        }
        scanPairs = []
    }

    func saveBatchCards(_ pairs: [(question: String, answer: String)],
                        toDeck deck: FlashcardDeck) async {
        guard let deckId = deck.id else { return }
        isSaving = true
        defer { isSaving = false }
        for pair in pairs where !pair.question.isEmpty {
            let card = Flashcard(
                deckId: deckId, question: pair.question,
                answer: pair.answer, timesAttempted: 0, timesCorrect: 0
            )
            try? await FirestoreService.shared.saveCard(card, toDeck: deckId)
        }
        var updated        = deck
        updated.cardCount += pairs.count
        _ = try? await FirestoreService.shared.saveFlashcardDeck(updated)
        if let idx = decks.firstIndex(where: { $0.id == deckId }) {
            decks[idx].cardCount += pairs.count
        }
    }

    // Review operations

    func startReview(for deck: FlashcardDeck) async {
        await loadCards(for: deck)
        currentCards.shuffle()
    }

    func markCorrect() async {
        correctCount += 1
        await updateCard(correct: true)
    }

    func markRetry() async {
        retryCount += 1
        await updateCard(correct: false)
    }

    private func updateCard(correct: Bool) async {
        guard var card = currentCard, !card.deckId.isEmpty else {
            advanceReview(); return
        }
        card.timesAttempted += 1
        if correct { card.timesCorrect += 1 }
        // Update local state
        currentCards[reviewIndex] = card
        try? await FirestoreService.shared.saveCard(card, toDeck: card.deckId)
        advanceReview()
    }

    private func advanceReview() {
        showingAnswer = false
        reviewIndex  += 1
    }

    func resetReview() {
        reviewIndex   = 0
        correctCount  = 0
        retryCount    = 0
        showingAnswer = false
        currentCards.shuffle()
    }

    //Accuracy helpers

    var sessionAccuracy: Double {
        let total = correctCount + retryCount
        guard total > 0 else { return 0 }
        return Double(correctCount) / Double(total)
    }
}
