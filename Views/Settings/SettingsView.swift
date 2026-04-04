import SwiftUI
import FirebaseAuth

struct SettingsView: View {

    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @AppStorage("preferredDuration") private var preferredDuration: Int = 25
    @AppStorage("preferredSound")    private var preferredSound: String = "Rain"
    @AppStorage("notificationsOn")   private var notificationsOn: Bool = true
    @AppStorage("biometricEnabled")  private var biometricEnabled: Bool = false

    var body: some View {
        NavigationStack {
            Form {

                // ── Account info (read-only) ───────────────────────────
                Section("Account") {
                    Label(authVM.profileEmail, systemImage: "envelope.fill")
                        .foregroundColor(.nestDark)

                    Label(authVM.profileDisplayName.isEmpty ? "—" : authVM.profileDisplayName,
                          systemImage: "person.fill")
                        .foregroundColor(.nestDark)
                }

                // ── Pomodoro preferences ───────────────────────────────
                Section("Focus Preferences") {
                    Stepper(
                        "Session Duration: \(preferredDuration) min",
                        value: $preferredDuration,
                        in: 5...60,
                        step: 5
                    )

                    Picker("Default Sound", selection: $preferredSound) {
                        ForEach(AmbientSound.allCases, id: \.rawValue) { s in
                            Text(s.rawValue).tag(s.rawValue)
                        }
                    }
                }

                // ── Notifications ──────────────────────────────────────
                Section("Notifications") {
                    Toggle("Enable Reminders", isOn: $notificationsOn)
                        .tint(.nestPurple)
                }

                // ── Security ───────────────────────────────────────────
                Section("Security") {
                    Toggle("Face ID for Notes Vault", isOn: $biometricEnabled)
                        .tint(.nestPurple)
                }

                // ── About ──────────────────────────────────────────────
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.appVersionString)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.nestPurple)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.nestPurple)
                }
            }
        }
    }
}

// MARK: - Bundle helper
private extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
