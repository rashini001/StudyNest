import Foundation
import FirebaseFirestore

struct PomodoroRecord: Codable, Identifiable {
    var id: String?
    var userId: String
    var cyclesCompleted: Int
    var totalWorkMinutes: Int
    var subjectTag: String
    var ambientSoundUsed: String
    var recordedAt: Date

    init(id: String? = nil, userId: String, cyclesCompleted: Int,
         totalWorkMinutes: Int, subjectTag: String,
         ambientSoundUsed: String, recordedAt: Date) {
        self.id = id
        self.userId = userId
        self.cyclesCompleted = cyclesCompleted
        self.totalWorkMinutes = totalWorkMinutes
        self.subjectTag = subjectTag
        self.ambientSoundUsed = ambientSoundUsed
        self.recordedAt = recordedAt
    }

    // Firestore read
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.cyclesCompleted = data["cyclesCompleted"] as? Int ?? 0
        self.totalWorkMinutes = data["totalWorkMinutes"] as? Int ?? 0
        self.subjectTag = data["subjectTag"] as? String ?? ""
        self.ambientSoundUsed = data["ambientSoundUsed"] as? String ?? ""
        self.recordedAt = (data["recordedAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    //Firestore write
    func toFirestoreData() -> [String: Any] {
        return [
            "userId": userId,
            "cyclesCompleted": cyclesCompleted,
            "totalWorkMinutes": totalWorkMinutes,
            "subjectTag": subjectTag,
            "ambientSoundUsed": ambientSoundUsed,
            "recordedAt": Timestamp(date: recordedAt)
        ]
    }
}
