import Foundation
import FirebaseFirestore

struct PDFNote: Codable, Identifiable {
    var id: String?
    var userId: String
    var title: String
    var subject: String
    var localFileName: String
    var pageCount: Int
    var isScanned: Bool
    var uploadedAt: Date

    init(id: String? = nil, userId: String, title: String, subject: String,
         localFileName: String, pageCount: Int, isScanned: Bool, uploadedAt: Date) {
        self.id = id
        self.userId = userId
        self.title = title
        self.subject = subject
        self.localFileName = localFileName
        self.pageCount = pageCount
        self.isScanned = isScanned
        self.uploadedAt = uploadedAt
    }

    //Firestore read
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.title = data["title"] as? String ?? ""
        self.subject = data["subject"] as? String ?? ""
        self.localFileName = data["localFileName"] as? String ?? ""
        self.pageCount = data["pageCount"] as? Int ?? 0
        self.isScanned = data["isScanned"] as? Bool ?? false
        self.uploadedAt = (data["uploadedAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    //Firestore write
    func toFirestoreData() -> [String: Any] {
        return [
            "userId": userId,
            "title": title,
            "subject": subject,
            "localFileName": localFileName,
            "pageCount": pageCount,
            "isScanned": isScanned,
            "uploadedAt": Timestamp(date: uploadedAt)
        ]
    }
}
