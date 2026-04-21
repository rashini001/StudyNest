import Foundation
import FirebaseFirestore
import CoreLocation

struct StudySpot: Codable, Identifiable {
    var id: String?
    var userId: String
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var category: String
    var rating: Int
    var personalNote: String
    var savedAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(id: String? = nil, userId: String, name: String, address: String,
         latitude: Double, longitude: Double, category: String,
         rating: Int, personalNote: String, savedAt: Date) {
        self.id = id
        self.userId = userId
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.rating = rating
        self.personalNote = personalNote
        self.savedAt = savedAt
    }

    //Firestore read
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.name = data["name"] as? String ?? ""
        self.address = data["address"] as? String ?? ""
        self.latitude = data["latitude"] as? Double ?? 0
        self.longitude = data["longitude"] as? Double ?? 0
        self.category = data["category"] as? String ?? "other"
        self.rating = data["rating"] as? Int ?? 1
        self.personalNote = data["personalNote"] as? String ?? ""
        self.savedAt = (data["savedAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    //Firestore write
    func toFirestoreData() -> [String: Any] {
        return [
            "userId": userId,
            "name": name,
            "address": address,
            "latitude": latitude,
            "longitude": longitude,
            "category": category,
            "rating": rating,
            "personalNote": personalNote,
            "savedAt": Timestamp(date: savedAt)
        ]
    }
}
