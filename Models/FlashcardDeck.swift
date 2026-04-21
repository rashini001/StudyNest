import Foundation
import FirebaseFirestore

struct FlashcardDeck: Codable, Identifiable {
    var id: String?
    var userId: String
    var title: String
    var subject: String
    var cardCount: Int
    var createdAt: Date

    init(id: String? = nil, userId: String, title: String,
         subject: String, cardCount: Int, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.title = title
        self.subject = subject
        self.cardCount = cardCount
        self.createdAt = createdAt
    }

    // Firestore read
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.title = data["title"] as? String ?? ""
        self.subject = data["subject"] as? String ?? ""
        self.cardCount = data["cardCount"] as? Int ?? 0
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    //Firestore write
    func toFirestoreData() -> [String: Any] {
        return [
            "userId": userId,
            "title": title,
            "subject": subject,
            "cardCount": cardCount,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}
