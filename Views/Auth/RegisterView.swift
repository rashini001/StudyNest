import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name            = ""
    @State private var email           = ""
    @State private var password        = ""
    @State private var confirmPassword = ""
    @State private var cardOpacity: Double  = 0
    @State private var cardOffset: CGFloat  = 40

    var body: some View {
        ZStack {
            LinearGradient(colors: [.nestPink, .nestPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            GeometryReader { geo in
                Circle().fill(Color.white.opacity(0.08))
                    .frame(width: geo.size.width * 0.65)
                    .offset(x: geo.size.width * 0.35, y: geo.size.height * 0.65)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 50)

                    VStack(spacing: 8) {
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 44)).foregroundColor(.white.opacity(0.9))
                        Spacer().frame(height: 6)
                        Text("Create Your Account")
                            .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.white)
                        Text("Start your journey here...")
                            .font(.subheadline).foregroundColor(.white.opacity(0.8))
                    }

                    Spacer().frame(height: 36)

                    VStack(spacing: 16) {
                        NestField(label: "Full Name", placeholder: "Enter your name", text: $name)
                        NestField(label: "Email", placeholder: "Enter your email", text: $email, keyboard: .emailAddress)
                        NestSecureField(label: "Password", placeholder: "Min 6 characters", text: $password)
                        NestSecureField(label: "Confirm Password", placeholder: "Re-enter password", text: $confirmPassword)

                        if !authVM.errorMessage.isEmpty {
                            Text(authVM.errorMessage).font(.caption).foregroundColor(.red).multilineTextAlignment(.center)
                        }

                        Button {
                            guard password == confirmPassword else { authVM.errorMessage = "Passwords do not match"; return }
                           
                            Task { await authVM.register(email: email, password: password, name: name) }
                        } label: {
                            ZStack {
                                if authVM.isLoading {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Sign Up").font(.headline).fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(LinearGradient(colors: [.nestPink, .nestPurple], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white).cornerRadius(14)
                            .shadow(color: .nestPink.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .disabled(authVM.isLoading)
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
                    .padding(.horizontal, 24)
                    .opacity(cardOpacity)
                    .offset(y: cardOffset)

                    Spacer().frame(height: 28)

                    Button { dismiss() } label: {
                        HStack(spacing: 4) {
                            Text("Already have an account?").foregroundColor(.white.opacity(0.8))
                            Text("Sign In").fontWeight(.bold).foregroundColor(.white)
                        }.font(.subheadline)
                    }
                    .opacity(cardOpacity)
                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55).delay(0.1)) { cardOpacity = 1; cardOffset = 0 }
        }
    }
}

// MARK: - Reusable field components
struct NestField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).fontWeight(.semibold).foregroundColor(.nestDark.opacity(0.7))
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .padding(14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.nestPurple.opacity(0.2), lineWidth: 1))
        }
    }
}

struct NestSecureField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).fontWeight(.semibold).foregroundColor(.nestDark.opacity(0.7))
            SecureField(placeholder, text: $text)
                .padding(14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.nestPurple.opacity(0.2), lineWidth: 1))
        }
    }
}
