import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    var id: String?
    var displayName: String
    var email: String
    var preferredSessionDuration: Int
    var preferredAmbientSound: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, displayName, email
        case preferredSessionDuration, preferredAmbientSound, createdAt
    }

    init(id: String? = nil, displayName: String, email: String,
         preferredSessionDuration: Int, preferredAmbientSound: String, createdAt: Date) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.preferredSessionDuration = preferredSessionDuration
        self.preferredAmbientSound = preferredAmbientSound
        self.createdAt = createdAt
    }

    //Firestore read
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.displayName = data["displayName"] as? String ?? ""
        self.email = data["email"] as? String ?? ""
        self.preferredSessionDuration = data["preferredSessionDuration"] as? Int ?? 25
        self.preferredAmbientSound = data["preferredAmbientSound"] as? String ?? "rain"
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    //Firestore write
    func toFirestoreData() -> [String: Any] {
        return [
            "displayName": displayName,
            "email": email,
            "preferredSessionDuration": preferredSessionDuration,
            "preferredAmbientSound": preferredAmbientSound,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}
