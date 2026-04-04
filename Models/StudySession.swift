import Foundation
import FirebaseFirestore

struct StudySession: Codable, Identifiable {
    var id: String?
    var userId: String
    var subject: String
    var startTime: Date
    var endTime: Date
    var notes: String
    var isCompleted: Bool
    var calendarEventId: String?
    var createdAt: Date

    // Computed — not stored in Firestore
    var computedDuration: Int {
        max(0, Int(endTime.timeIntervalSince(startTime) / 60))
    }

    // MARK: - Memberwise init
    init(id: String? = nil, userId: String, subject: String,
         startTime: Date, endTime: Date, notes: String,
         isCompleted: Bool, calendarEventId: String? = nil, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.subject = subject
        self.startTime = startTime
        self.endTime = endTime
        self.notes = notes
        self.isCompleted = isCompleted
        self.calendarEventId = calendarEventId
        self.createdAt = createdAt
    }

    // MARK: - Firestore read
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.subject = data["subject"] as? String ?? ""
        self.startTime = (data["startTime"] as? Timestamp)?.dateValue() ?? Date()
        self.endTime = (data["endTime"] as? Timestamp)?.dateValue() ?? Date()
        self.notes = data["notes"] as? String ?? ""
        self.isCompleted = data["isCompleted"] as? Bool ?? false
        self.calendarEventId = data["calendarEventId"] as? String
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    // MARK: - Firestore write
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "subject": subject,
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: endTime),
            "notes": notes,
            "isCompleted": isCompleted,
            "createdAt": Timestamp(date: createdAt)
        ]
        if let calId = calendarEventId { data["calendarEventId"] = calId }
        return data
    }
}
