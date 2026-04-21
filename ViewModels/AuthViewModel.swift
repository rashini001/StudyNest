import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var isLoggedIn = false
    @Published var errorMessage = ""
    @Published var isLoading = false

    @Published var profileDisplayName: String = ""
    @Published var profileEmail: String = ""

    @Published var preferredDuration: Int = 25
    @Published var preferredSound: String = "Rain"
    @Published var notificationsOn: Bool = true

    @Published var faceIDEnabled: Bool {
        didSet { UserDefaults.standard.set(faceIDEnabled, forKey: "faceIDEnabled") }
    }

    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        faceIDEnabled = UserDefaults.standard.bool(forKey: "faceIDEnabled")

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isLoggedIn = user != nil
            self?.syncProfile(from: user)
            if let uid = user?.uid {
                Task { await self?.loadPreferences(uid: uid) }
            }
        }
    }

    deinit {
        if let h = authStateHandle { Auth.auth().removeStateDidChangeListener(h) }
    }

    var initials: String {
        let parts = profileDisplayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty
            ? String(profileEmail.prefix(1)).uppercased()
            : String(letters).uppercased()
    }

    func signIn(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."; return
        }
        isLoading = true; errorMessage = ""
        do {
            let result = try await AuthService.shared.signIn(email: email, password: password)
            if let token = result.user.refreshToken {
                KeychainService.shared.save(token, forKey: .firebaseRefreshToken)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func register(email: String, password: String, name: String) async {
        guard !name.isEmpty, !email.isEmpty, password.count >= 6 else {
            errorMessage = "Name, email required. Password min 6 chars."; return
        }
        isLoading = true; errorMessage = ""
        do {
            let result = try await AuthService.shared.register(
                email: email, password: password, name: name
            )
            if let token = result.user.refreshToken {
                KeychainService.shared.save(token, forKey: .firebaseRefreshToken)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        KeychainService.shared.delete(forKey: .firebaseRefreshToken)
        try? AuthService.shared.signOut()
    }

    //Face ID sign-in
    func signInWithFaceID() async {
        guard KeychainService.shared.load(forKey: .firebaseRefreshToken) != nil else {
            errorMessage = "No saved session. Please sign in with your password first."
            return
        }

        let success = await BiometricService.shared.authenticate(reason: "Sign in to StudyNest")
        guard success else {
            errorMessage = "Face ID authentication failed."
            return
        }

        if Auth.auth().currentUser != nil {
            isLoggedIn = true
            syncProfile(from: Auth.auth().currentUser)
        } else {
            errorMessage = "Session expired. Please sign in with your password."
        }
    }

    //Profile

    func refreshProfile() {
        syncProfile(from: Auth.auth().currentUser)
    }

    //Preferences

    func loadPreferences(uid: String) async {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            guard let data = doc.data() else { return }
            preferredDuration = data["preferredSessionDuration"] as? Int    ?? 25
            preferredSound    = data["preferredAmbientSound"]    as? String ?? "Rain"
            notificationsOn   = data["notificationsOn"]          as? Bool   ?? true
            // Sync faceIDEnabled from Firestore and keep UserDefaults in step.
            let remoteValue   = data["faceIDEnabled"]            as? Bool   ?? false
            faceIDEnabled     = remoteValue
        } catch {
            print("StudyNest: loadPreferences error: \(error.localizedDescription)")
        }
    }

    func savePreferences() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let data: [String: Any] = [
            "preferredSessionDuration": preferredDuration,
            "preferredAmbientSound":    preferredSound,
            "notificationsOn":          notificationsOn,
            "faceIDEnabled":            faceIDEnabled
        ]
        do {
            try await db.collection("users").document(uid).updateData(data)
        } catch {
            print("StudyNest: savePreferences error: \(error.localizedDescription)")
        }
    }

    //Face ID toggle

    func enableFaceID() async -> Bool {
        let success = await BiometricService.shared.authenticate(
            reason: "Confirm your identity to enable Face ID login"
        )
        guard success else { return false }

        if let token = Auth.auth().currentUser?.refreshToken {
            KeychainService.shared.save(token, forKey: .firebaseRefreshToken)
        }
        faceIDEnabled = true
        await savePreferences()
        return true
    }

    func disableFaceID() async {
        faceIDEnabled = false
        KeychainService.shared.delete(forKey: .firebaseRefreshToken)
        await savePreferences()
    }

    private func syncProfile(from user: FirebaseAuth.User?) {
        profileDisplayName = user?.displayName ?? ""
        profileEmail       = user?.email       ?? ""
    }
}
