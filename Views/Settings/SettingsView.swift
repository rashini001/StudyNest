import SwiftUI
import FirebaseAuth

struct AppTextSize {
    
    static let steps: [String] = ["Small", "Medium", "Large", "X-Large", "XX-Large"]

   
    static func scale(for index: Int) -> CGFloat {
        switch index {
        case 0: return 0.80
        case 1: return 0.90
        case 2: return 1.00  
        case 3: return 1.20
        case 4: return 1.40
        default: return 1.00
        }
    }

    static func font(_ style: Font.TextStyle, index: Int) -> Font {
        let base: CGFloat
        switch style {
        case .largeTitle:  base = 34
        case .title:       base = 28
        case .title2:      base = 22
        case .title3:      base = 20
        case .headline:    base = 17
        case .body:        base = 17
        case .callout:     base = 16
        case .subheadline: base = 15
        case .footnote:    base = 13
        case .caption:     base = 12
        case .caption2:    base = 11
        @unknown default:  base = 17
        }
        return .system(size: base * scale(for: index))
    }
}

// SettingsView
struct SettingsView: View {

    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var duration: Int  = 25
    @State private var sound: String  = "Rain"
    @State private var notifs: Bool   = true
    @State private var faceID: Bool   = false

    @State private var showFaceIDError = false
    @State private var faceIDErrorMsg  = ""

    @AppStorage("appTextSizeIndex") private var textSizeIndex: Int = 2

    // Reduce Motion  
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                focusSection
                notificationsSection
                textSizeSection            
                reduceMotionSection         
                if BiometricService.shared.isFaceIDAvailable {
                    faceIDSection
                }
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.nestPurple)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.nestPurple)
                        .accessibilityLabel("Done")
                        .accessibilityHint("Close Settings.")
                }
            }
            .onAppear {
                duration = authVM.preferredDuration
                sound    = authVM.preferredSound
                notifs   = authVM.notificationsOn
                faceID   = authVM.faceIDEnabled
                UIAccessibility.post(notification: .screenChanged, argument: "Settings")
            }
        }
    }

    // Account Section
    private var accountSection: some View {
        Section("Account") {
            Label(authVM.profileEmail, systemImage: "envelope.fill")
                .foregroundColor(.nestDark)
                .accessibilityLabel("Email address: \(authVM.profileEmail)")
                .accessibilityHint("Your account email")

            Label(
                authVM.profileDisplayName.isEmpty ? "—" : authVM.profileDisplayName,
                systemImage: "person.fill"
            )
            .foregroundColor(.nestDark)
            .accessibilityLabel(
                authVM.profileDisplayName.isEmpty
                ? "Display Name Not Set"
                : "Display Name : \(authVM.profileDisplayName)"
            )
        }
    }

    //Focus Preferences Section
    private var focusSection: some View {
        Section("Focus Preferences") {
            Stepper(
                "Session Duration: \(duration) min",
                value: $duration, in: 5...60, step: 5
            )
            .onChange(of: duration) { _ in persistPreferences() }
            .accessibilityLabel("Session Duration")
            .accessibilityValue("\(duration) min")
            .accessibilityHint("Swipe up or down to adjust in 5 min steps. Range is 5 to 60 min.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: if duration < 60 { duration += 5 }
                case .decrement: if duration > 5  { duration -= 5 }
                @unknown default: break
                }
                persistPreferences()
            }

            Picker("Default Sound", selection: $sound) {
                ForEach(AmbientSound.allCases, id: \.rawValue) { s in
                    Text(s.rawValue).tag(s.rawValue)
                }
            }
            .onChange(of: sound) { _ in persistPreferences() }
            .accessibilityLabel("Default Sound")
            .accessibilityValue(sound)
            .accessibilityHint("Opens a list of ambient sound to choose from.")
        }
    }

    // Notifications Section
    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Enable Reminders", isOn: $notifs)
                .tint(.nestPurple)
                .onChange(of: notifs) { _ in persistPreferences() }
                .accessibilityLabel("Enable Study Reminders")
                .accessibilityValue(notifs ? "On" : "Off")
                .accessibilityHint("Toggles push notifications for study sessions and tasks")
        }
    }

    // Text Size Section  
    private var textSizeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {

                HStack {
                    Image(systemName: "textformat.size")
                        .foregroundColor(.nestPurple)
                        .accessibilityHidden(true)

                    Text("Text Size")
                        .font(AppTextSize.font(.headline, index: textSizeIndex))
                        .foregroundColor(.nestDark)

                    Spacer()

                    Text(AppTextSize.steps[textSizeIndex])
                        .font(AppTextSize.font(.caption, index: textSizeIndex))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.nestPurple.opacity(0.15))
                        .foregroundColor(.nestPurple)
                        .clipShape(Capsule())
                }

                Slider(
                    value: Binding(
                        get: { Double(textSizeIndex) },
                        set: { textSizeIndex = Int($0.rounded()) }
                    ),
                    in: 0...4,
                    step: 1
                )
                .tint(.nestPurple)
                .accessibilityLabel("Text size slider")
                .accessibilityValue(AppTextSize.steps[textSizeIndex])
                .accessibilityHint("Slide left for smaller text, right for larger text.")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: if textSizeIndex < 4 { textSizeIndex += 1 }
                    case .decrement: if textSizeIndex > 0 { textSizeIndex -= 1 }
                    @unknown default: break
                    }
                    
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Text size changed to \(AppTextSize.steps[textSizeIndex])"
                    )
                }

                HStack {
                    Text("A")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("A")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
                .accessibilityHidden(true)  

                Text("The quick brown fox jumps over the lazy dog.")
                    .font(AppTextSize.font(.body, index: textSizeIndex))
                    .foregroundColor(.nestDark)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(
                        "Preview: The quick brown fox jumps over the lazy dog. " +
                        "Current size: \(AppTextSize.steps[textSizeIndex])."
                    )
            }
            .padding(.vertical, 6)
            .animation(.easeInOut(duration: 0.2), value: textSizeIndex)

        } header: {
            Text("Text Size")
        } footer: {
            Text("Adjusts text size throughout StudyNest.")
                .font(.caption)
        }
    }


    //  Reduce Motion Section 
   
    private var reduceMotionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {

                HStack(spacing: 10) {
                    Image(systemName: reduceMotion ? "hand.raised.fill" : "wand.and.stars")
                        .foregroundColor(.nestPurple)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reduce Motion")
                            .font(AppTextSize.font(.headline, index: textSizeIndex))
                            .foregroundColor(.nestDark)
                        Text(reduceMotion ? "Active — animations are off" : "Off — animations are on")
                            .font(AppTextSize.font(.caption, index: textSizeIndex))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(reduceMotion ? "ON" : "OFF")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(reduceMotion ? Color.nestPurple : Color.gray.opacity(0.2))
                        .foregroundColor(reduceMotion ? .white : .secondary)
                        .clipShape(Capsule())
                        .accessibilityHidden(true)
                }

                Divider()

                DemoAnimationCard(reduceMotion: reduceMotion)
            }
            .padding(.vertical, 4)
           
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Reduce Motion is currently \(reduceMotion ? "on" : "off"). " +
                "\(reduceMotion ? "Animations are disabled." : "Animations are enabled.")"
            )

        } header: {
            Text("Motion")
        } footer: {
            Text("Toggle Reduce Motion in iPhone Settings → Accessibility → Motion.")
                .font(.caption)
        }
    }

    // Face ID Section
    private var faceIDSection: some View {
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
                            UIAccessibility.post(
                                notification: .announcement,
                                argument: faceIDErrorMsg
                            )
                        } else {
                            UIAccessibility.post(
                                notification: .announcement,
                                argument: "Face ID Login enabled."
                            )
                        }
                    } else {
                        await authVM.disableFaceID()
                        UIAccessibility.post(
                            notification: .announcement,
                            argument: "Face ID Login disabled."
                        )
                    }
                }
            }
            .accessibilityLabel("Face ID Login")
            .accessibilityValue(faceID ? "Enabled" : "Disabled")
            .accessibilityHint(
                faceID
                ? "Double Tap to disable Face ID Login."
                : "Double Tap to enable Face ID Login."
            )

            if showFaceIDError {
                Text(faceIDErrorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .accessibilityHidden(true)
            }

        } header: {
            Text("Security")
        } footer: {
            Text(faceID
                 ? "Face ID will be used to sign in on next launch."
                 : "Enable to sign in with Face ID instead of your password.")
                .font(.caption)
                .accessibilityHidden(true)
        }
    }

    // About Section
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.appVersionString)
                    .foregroundColor(.gray)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("App version \(Bundle.main.appVersionString)")
        }
    }

    // Persist
    private func persistPreferences() {
        authVM.preferredDuration = duration
        authVM.preferredSound    = sound
        authVM.notificationsOn   = notifs
        Task { await authVM.savePreferences() }
    }
}

private struct DemoAnimationCard: View {
    let reduceMotion: Bool

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 16) {
            Text(reduceMotion ? "Static preview:" : "Live preview:")
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.nestPurple.opacity(0.7))
                        .frame(width: 12, height: 12)
                        
                        .offset(y: (!reduceMotion && isAnimating) ? -8 : 0)
                        .animation(
                            reduceMotion
                            ? .none   
                            : Animation
                                .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: isAnimating
                        )
                }
            }

            Spacer()

            Text(reduceMotion ? "No motion" : "Bouncing")
                .font(.caption2)
                .foregroundColor(reduceMotion ? .secondary : .nestPurple)
                .accessibilityHidden(true)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .accessibilityHidden(true)   
        .onAppear {
            if !reduceMotion { isAnimating = true }
        }
        .onChange(of: reduceMotion) { newValue in
            isAnimating = !newValue
        }
    }
}

// Bundle Helper
private extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}