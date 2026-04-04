import Foundation
import Combine

@MainActor
final class FlashcardViewModel: ObservableObject {

    @Published var decks: [FlashcardDeck]  = []
    @Published var currentCards: [Flashcard] = []
    @Published var reviewIndex: Int     = 0
    @Published var showingAnswer: Bool  = false
    @Published var correctCount: Int    = 0
    @Published var retryCount: Int      = 0
    @Published var isLoading: Bool      = false

    init() { }

    // MARK: - Computed

    var currentCard: Flashcard? { currentCards[safe: reviewIndex] }
    var reviewComplete: Bool    { reviewIndex >= currentCards.count }

    // MARK: - Deck operations

    func loadDecks() async {
        isLoading = true
        guard let userId = AuthService.shared.currentUserId else { isLoading = false; return }
        decks = (try? await FirestoreService.shared.fetchDecks(for: userId)) ?? []
        isLoading = false
    }

    func createDeck(title: String, subject: String) async {
        guard let userId = AuthService.shared.currentUserId else { return }
        let deck = FlashcardDeck(
            userId: userId, title: title,
            subject: subject, cardCount: 0, createdAt: Date()
        )
        let id = (try? await FirestoreService.shared.saveFlashcardDeck(deck)) ?? ""
        var saved   = deck
        saved.id    = id
        decks.insert(saved, at: 0)
    }

    // MARK: - Card operations

    func loadCards(for deck: FlashcardDeck) async {
        guard let id = deck.id else { return }
        currentCards  = (try? await FirestoreService.shared.fetchCards(for: id)) ?? []
        reviewIndex   = 0
        correctCount  = 0
        retryCount    = 0
        showingAnswer = false
    }

    func addCard(question: String, answer: String, toDeck deck: FlashcardDeck) async {
        guard let deckId = deck.id else { return }
        let card = Flashcard(
            deckId: deckId, question: question,
            answer: answer, timesAttempted: 0, timesCorrect: 0
        )
        try? await FirestoreService.shared.saveCard(card, toDeck: deckId)
    }

    func saveBatchCards(_ pairs: [(question: String, answer: String)],
                        toDeck deck: FlashcardDeck) async {
        guard let deckId = deck.id else { return }
        for pair in pairs {
            let card = Flashcard(
                deckId: deckId, question: pair.question,
                answer: pair.answer, timesAttempted: 0, timesCorrect: 0
            )
            try? await FirestoreService.shared.saveCard(card, toDeck: deckId)
        }
    }

    // MARK: - Review operations

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
        try? await FirestoreService.shared.saveCard(card, toDeck: card.deckId)
        advanceReview()
    }

    private func advanceReview() {
        showingAnswer = false
        reviewIndex  += 1
    }
}
