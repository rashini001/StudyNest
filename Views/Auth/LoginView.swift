import SwiftUI

struct LoginView: View {

    @EnvironmentObject var authVM: AuthViewModel

    @State private var email        = ""
    @State private var password     = ""
    @State private var showRegister = false

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

                //Login card
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

                    // Error message
                    if !authVM.errorMessage.isEmpty {
                        Text(authVM.errorMessage)
                            .foregroundColor(.yellow)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }

                    // Sign In button
                    Button("Sign In") {
                        Task { await authVM.signIn(email: email, password: password) }
                    }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(authVM.isLoading)
                    if authVM.faceIDEnabled && BiometricService.shared.isFaceIDAvailable {
                        Button {
                            Task { await authVM.signInWithFaceID() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "faceid")
                                    .font(.title3)
                                Text("Sign in with Face ID")
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
}
