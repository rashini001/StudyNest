import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showEditProfile = false
    @State private var showSettings    = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Avatar + name header ──────────────────────────────
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.nestPink, .nestPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 90, height: 90)

                            Text(authVM.initials)
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text(authVM.profileDisplayName)
                            .font(.title2).bold()
                            .foregroundColor(.nestDark)

                        Text(authVM.profileEmail)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 16)

                    // ── Action cards ─────────────────────────────────────
                    VStack(spacing: 0) {
                        ProfileRow(icon: "person.fill",
                                   label: "Edit Profile",
                                   color: .nestPurple) {
                            showEditProfile = true
                        }
                        Divider().padding(.leading, 56)

                        ProfileRow(icon: "gearshape.fill",
                                   label: "Settings",
                                   color: .blue) {
                            showSettings = true
                        }
                        Divider().padding(.leading, 56)

                        ProfileRow(icon: "rectangle.portrait.and.arrow.right",
                                   label: "Sign Out",
                                   color: .red,
                                   isDestructive: true) {
                            showSignOutAlert = true
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.nestPurple)
                }
            }
            // ── Sheets ───────────────────────────────────────────────────
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authVM)
            }
            // ── Sign-out alert ───────────────────────────────────────────
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authVM.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

// MARK: - ProfileRow helper
private struct ProfileRow: View {
    let icon: String
    let label: String
    let color: Color
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .foregroundColor(color)
                }

                Text(label)
                    .foregroundColor(isDestructive ? .red : .nestDark)
                    .font(.body)

                Spacer()

                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}
