import SwiftUI
import FirebaseAuth

struct EditProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var displayName = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var successMessage = ""
    @State private var errorMessage   = ""
    @State private var isLoading      = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.nestPink, .nestPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        Text(initials(from: displayName))
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 12)

                    // Name section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Display Name", systemImage: "person.fill")
                            .font(.caption).foregroundColor(.nestPurple)

                        TextField("Your name", text: $displayName)
                            .padding()
                            .background(Color.nestLightPurple)
                            .cornerRadius(12)
                    }

                    // Password section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("New Password (optional)", systemImage: "lock.fill")
                            .font(.caption).foregroundColor(.nestPurple)

                        SecureField("New password (min 6 chars)", text: $newPassword)
                            .padding()
                            .background(Color.nestLightPurple)
                            .cornerRadius(12)

                        SecureField("Confirm new password", text: $confirmPassword)
                            .padding()
                            .background(Color.nestLightPurple)
                            .cornerRadius(12)
                    }

                    // Messages
                    if !successMessage.isEmpty {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    // Save button
                    Button {
                        Task { await saveChanges() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.nestPink, .nestPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .bold()
                        }
                    }
                    .disabled(isLoading)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.nestPurple)
                }
            }
            .onAppear {
                displayName = authVM.profileDisplayName
            }
        }
    }

    // Helpers

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private func saveChanges() async {
        errorMessage   = ""
        successMessage = ""
        isLoading      = true

        let user = Auth.auth().currentUser

        if !displayName.isEmpty, displayName != authVM.profileDisplayName {
            let changeRequest = user?.createProfileChangeRequest()
            changeRequest?.displayName = displayName
            do {
                try await changeRequest?.commitChanges()
                authVM.refreshProfile()
                successMessage = "Name updated."
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                return
            }
        }

        if !newPassword.isEmpty {
            guard newPassword == confirmPassword else {
                errorMessage = "Passwords do not match."
                isLoading = false
                return
            }
            guard newPassword.count >= 6 else {
                errorMessage = "Password must be at least 6 characters."
                isLoading = false
                return
            }
            do {
                try await user?.updatePassword(to: newPassword)
                successMessage += " Password updated."
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                return
            }
        }

        isLoading = false
        if successMessage.isEmpty { successMessage = "No changes made." }
    }
}
