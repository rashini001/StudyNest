import Foundation
import FirebaseFirestore

enum TaskPriority: String, Codable, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var colorString: String {
        switch self {
        case .high:   return "red"
        case .medium: return "orange"
        case .low:    return "green"
        }
    }
}

struct StudyTask: Codable, Identifiable {
    var id: String?
    var userId: String
    var title: String
    var subject: String
    var dueDate: Date
    var priority: TaskPriority
    var isCompleted: Bool
    var notificationId: String?
    var calendarEventId: String?
    var createdAt: Date

    var isOverdue: Bool {
        !isCompleted && dueDate < Date()
    }

    init(id: String? = nil, userId: String, title: String, subject: String,
         dueDate: Date, priority: TaskPriority, isCompleted: Bool,
         notificationId: String? = nil, calendarEventId: String? = nil, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.title = title
        self.subject = subject
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = isCompleted
        self.notificationId = notificationId
        self.calendarEventId = calendarEventId
        self.createdAt = createdAt
    }

    //Firestore read
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.title = data["title"] as? String ?? ""
        self.subject = data["subject"] as? String ?? ""
        self.dueDate = (data["dueDate"] as? Timestamp)?.dateValue() ?? Date()
        self.priority = TaskPriority(rawValue: data["priority"] as? String ?? "Medium") ?? .medium
        self.isCompleted = data["isCompleted"] as? Bool ?? false
        self.notificationId = data["notificationId"] as? String
        self.calendarEventId = data["calendarEventId"] as? String
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    //Firestore write
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "title": title,
            "subject": subject,
            "dueDate": Timestamp(date: dueDate),
            "priority": priority.rawValue,
            "isCompleted": isCompleted,
            "createdAt": Timestamp(date: createdAt)
        ]
        if let notifId = notificationId { data["notificationId"] = notifId }
        if let calId = calendarEventId { data["calendarEventId"] = calId }
        return data
    }
}
