import Foundation
import FirebaseFirestore

struct Flashcard: Codable, Identifiable {
    var id: String?
    var deckId: String
    var question: String
    var answer: String
    var timesAttempted: Int
    var timesCorrect: Int

    var accuracy: Double {
        guard timesAttempted > 0 else { return 0 }
        return Double(timesCorrect) / Double(timesAttempted)
    }

    init(id: String? = nil, deckId: String, question: String,
         answer: String, timesAttempted: Int, timesCorrect: Int) {
        self.id = id
        self.deckId = deckId
        self.question = question
        self.answer = answer
        self.timesAttempted = timesAttempted
        self.timesCorrect = timesCorrect
    }

    //Firestore read
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.deckId = data["deckId"] as? String ?? ""
        self.question = data["question"] as? String ?? ""
        self.answer = data["answer"] as? String ?? ""
        self.timesAttempted = data["timesAttempted"] as? Int ?? 0
        self.timesCorrect = data["timesCorrect"] as? Int ?? 0
    }

    //Firestore write
    func toFirestoreData() -> [String: Any] {
        return [
            "deckId": deckId,
            "question": question,
            "answer": answer,
            "timesAttempted": timesAttempted,
            "timesCorrect": timesCorrect
        ]
    }
}
