import SwiftUI
import FirebaseAuth

struct SettingsView: View {

    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    // Local copies
    @State private var duration: Int   = 25
    @State private var sound: String   = "Rain"
    @State private var notifs: Bool    = true
    @State private var faceID: Bool    = false

    @State private var showFaceIDError = false
    @State private var faceIDErrorMsg  = ""

    var body: some View {
        NavigationStack {
            Form {

                //Account info
                Section("Account") {
                    Label(authVM.profileEmail, systemImage: "envelope.fill")
                        .foregroundColor(.nestDark)

                    Label(
                        authVM.profileDisplayName.isEmpty ? "—" : authVM.profileDisplayName,
                        systemImage: "person.fill"
                    )
                    .foregroundColor(.nestDark)
                }

                //  Pomodoro preferences
                Section("Focus Preferences") {
                    Stepper(
                        "Session Duration: \(duration) min",
                        value: $duration, in: 5...60, step: 5
                    )
                    .onChange(of: duration) { _ in persistPreferences() }

                    Picker("Default Sound", selection: $sound) {
                        ForEach(AmbientSound.allCases, id: \.rawValue) { s in
                            Text(s.rawValue).tag(s.rawValue)
                        }
                    }
                    .onChange(of: sound) { _ in persistPreferences() }
                }

                // Notifications
                Section("Notifications") {
                    Toggle("Enable Reminders", isOn: $notifs)
                        .tint(.nestPurple)
                        .onChange(of: notifs) { _ in persistPreferences() }
                }

                //  Security — Face ID
               
                if BiometricService.shared.isFaceIDAvailable {
                    Section {
                        Toggle(isOn: $faceID) {
                            Label("Face ID Login", systemImage: "faceid")
                        }
                        .tint(.nestPurple)
                        .onChange(of: faceID) { newValue in
                            showFaceIDError = false
                            Task {
                                if newValue {
                                    let ok = await authVM.enableFaceID()
                                    if !ok {
                                
                                        faceID = false
                                        faceIDErrorMsg = "Face ID confirmation failed. Try again."
                                        showFaceIDError = true
                                    }
                                } else {
                                    await authVM.disableFaceID()
                                }
                            }
                        }

                        if showFaceIDError {
                            Text(faceIDErrorMsg)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } header: {
                        Text("Security")
                    } footer: {
                        Text(faceID
                             ? "Face ID will be used to sign in on next launch."
                             : "Enable to sign in with Face ID instead of your password.")
                            .font(.caption)
                    }
                }

                //  About
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
           
            .onAppear {
                duration = authVM.preferredDuration
                sound    = authVM.preferredSound
                notifs   = authVM.notificationsOn
                faceID   = authVM.faceIDEnabled
            }
        }
    }


    private func persistPreferences() {
        authVM.preferredDuration = duration
        authVM.preferredSound    = sound
        authVM.notificationsOn   = notifs
        Task { await authVM.savePreferences() }
    }
}

// Bundle helper
private extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
