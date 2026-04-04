import Foundation
import FirebaseAuth
import Combine

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var isLoggedIn = false
    @Published var errorMessage = ""
    @Published var isLoading = false

    // Profile fields – kept in sync with Firebase Auth user
    @Published var profileDisplayName: String = ""
    @Published var profileEmail: String = ""

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isLoggedIn = user != nil
            self?.syncProfile(from: user)
        }
    }

    deinit {
        if let h = authStateHandle {
            Auth.auth().removeStateDidChangeListener(h)
        }
    }

    // MARK: - Computed

    /// "JD" style initials for the avatar circle
    var initials: String {
        let parts = profileDisplayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        if letters.isEmpty {
            return String(profileEmail.prefix(1)).uppercased()
        }
        return String(letters).uppercased()
    }

    // MARK: - Auth actions

    func signIn(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."; return
        }
        isLoading = true; errorMessage = ""
        do {
            try await AuthService.shared.signIn(email: email, password: password)
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
            try await AuthService.shared.register(email: email, password: password, name: name)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        try? AuthService.shared.signOut()
    }

    /// Call after editing the Firebase Auth profile so published values refresh immediately.
    func refreshProfile() {
        syncProfile(from: Auth.auth().currentUser)
    }

    // MARK: - Private

    private func syncProfile(from user: FirebaseAuth.User?) {
        profileDisplayName = user?.displayName ?? ""
        profileEmail       = user?.email       ?? ""
    }
}
