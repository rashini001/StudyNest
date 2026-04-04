import Foundation
import FirebaseAuth
import FirebaseFirestore

final class AuthService {
    static let shared = AuthService()
    private let db = Firestore.firestore()

    var currentUserId: String? { Auth.auth().currentUser?.uid }
    var isLoggedIn: Bool { Auth.auth().currentUser != nil }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func register(email: String, password: String, name: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = result.user.uid
        let profile = UserProfile(
            id: uid, displayName: name, email: email,
            preferredSessionDuration: 25,
            preferredAmbientSound: "rain",
            createdAt: Date()
        )
        try await db.collection("users").document(uid).setData(profile.toFirestoreData())
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
