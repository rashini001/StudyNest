import SwiftUI
internal import LocalAuthentication

struct LoginView: View {

    @EnvironmentObject var authVM: AuthViewModel

    @State private var email        = ""
    @State private var password     = ""
    @State private var showRegister = false
    @State private var biometricError = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.nestPurple, .nestPink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {

                Spacer()

                // ── Branding ──────────────────────────────────────────
                VStack(spacing: 6) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)

                    Text("StudyNest")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)

                    Text("Your Smart Study Companion")
                        .foregroundColor(.white.opacity(0.85))
                }

                // ── Login card ────────────────────────────────────────
                VStack(spacing: 16) {

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)

                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)

                    // Error messages
                    if !authVM.errorMessage.isEmpty {
                        Text(authVM.errorMessage)
                            .foregroundColor(.yellow)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    if !biometricError.isEmpty {
                        Text(biometricError)
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }

                    // Sign In button
                    Button("Sign In") {
                        Task { await authVM.signIn(email: email, password: password) }
                    }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(authVM.isLoading)

                    // Face ID button
                    if BiometricService.shared.biometricType != .none {
                        Button {
                            Task { await signInWithBiometric() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: biometricIcon)
                                    .font(.title3)
                                Text("Sign in with \(biometricLabel)")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(24)
                .background(Color.white.opacity(0.15))
                .cornerRadius(20)
                .padding(.horizontal)

                Button("Don't have an account? Register") {
                    showRegister = true
                }
                .foregroundColor(.white)

                Spacer()
            }
        }
        .sheet(isPresented: $showRegister) {
            RegisterView().environmentObject(authVM)
        }
    }

    // MARK: - Biometric helpers

    private var biometricIcon: String {
        BiometricService.shared.biometricType == .faceID ? "faceid" : "touchid"
    }

    private var biometricLabel: String {
        BiometricService.shared.biometricType == .faceID ? "Face ID" : "Touch ID"
    }

    private func signInWithBiometric() async {
        biometricError = ""
        let success = await BiometricService.shared.authenticate(
            reason: "Sign in to StudyNest"
        )
        if success {
            // Biometric only validates the local user — still need saved credentials
            // Try signing in with the last used email if password is pre-filled,
            // otherwise prompt the user to enter their password first.
            guard !email.isEmpty, !password.isEmpty else {
                biometricError = "Enter your email and password first, then use Face ID."
                return
            }
            await authVM.signIn(email: email, password: password)
        } else {
            biometricError = "Biometric authentication failed."
        }
    }
}
