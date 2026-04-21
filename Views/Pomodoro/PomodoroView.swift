import SwiftUI

struct PomodoroView: View {
    @StateObject private var vm = PomodoroViewModel()
    @EnvironmentObject var authVM: AuthViewModel

    // Controls the phase-end banner overlay
    @State private var showPhaseBanner = false

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Background ──
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {

                        // MARK: - Subject Tag Field
                        HStack(spacing: 10) {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.nestPurple)
                                .font(.caption)
                            TextField("Subject tag (e.g. Maths)", text: $vm.subjectTag)
                                .font(.subheadline)
                                .foregroundColor(.nestDark)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.nestPurple.opacity(0.06), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)

                        // MARK: - Phase Badge
                        HStack(spacing: 6) {
                            Text(vm.phase.emoji)
                                .font(.caption)
                            Text(vm.phase.displayLabel)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(phaseBadgeColour)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(phaseBadgeColour.opacity(0.12))
                        .cornerRadius(20)
                        .animation(.easeInOut, value: vm.phase)

                        // MARK: - Timer Ring
                        ZStack {
                            // Outer track
                            Circle()
                                .stroke(Color.nestLightPink, lineWidth: 18)
                                .frame(width: 250, height: 250)

                            // Break phase gets a calm green tint track
                            if vm.isOnBreak {
                                Circle()
                                    .stroke(Color.green.opacity(0.15), lineWidth: 18)
                                    .frame(width: 250, height: 250)
                            }

                            // Progress arc
                            Circle()
                                .trim(from: 0, to: vm.progress)
                                .stroke(
                                    LinearGradient(
                                        colors: vm.isOnBreak
                                            ? [.green, .teal]
                                            : [.nestPink, .nestPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                                )
                                .frame(width: 250, height: 250)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: vm.progress)

                            // Inner glow circle
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            (vm.isOnBreak ? Color.green : Color.nestPink).opacity(0.08),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 60,
                                        endRadius: 120
                                    )
                                )
                                .frame(width: 220, height: 220)

                            // Time + status text
                            VStack(spacing: 6) {
                                Text(vm.formattedTime)
                                    .font(.system(size: 54, weight: .bold, design: .rounded))
                                    .foregroundColor(.nestDark)
                                    .contentTransition(.numericText())
                                    .animation(.easeInOut, value: vm.secondsRemaining)

                                Text(vm.isRunning
                                     ? (vm.isOnBreak ? "Resting…" : "Stay focused!")
                                     : (vm.phase == .idle ? "Ready" : "Paused"))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .animation(.easeInOut, value: vm.isRunning)
                            }
                        }

                        // MARK: - Cycle Dots
                        VStack(spacing: 6) {
                            HStack(spacing: 12) {
                                ForEach(0..<4, id: \.self) { i in
                                    Circle()
                                        .fill(i < vm.cyclesCompleted % 4
                                              ? AnyShapeStyle(LinearGradient(
                                                    colors: [.nestPink, .nestPurple],
                                                    startPoint: .leading, endPoint: .trailing))
                                              : AnyShapeStyle(Color.nestLightPurple))
                                        .frame(width: 14, height: 14)
                                        .scaleEffect(i < vm.cyclesCompleted % 4 ? 1.1 : 1.0)
                                        .animation(.spring(), value: vm.cyclesCompleted)
                                }
                            }
                            Text("\(vm.cyclesCompleted) cycle\(vm.cyclesCompleted == 1 ? "" : "s") completed")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }

                        // MARK: - Ambient Sound Selector
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption)
                                    .foregroundColor(.nestPurple)
                                Text("Ambient Sound")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                                Spacer()
                                if vm.isOnBreak {
                                    Text("Paused during break")
                                        .font(.caption2)
                                        .foregroundColor(.gray.opacity(0.7))
                                }
                            }
                            .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(AmbientSound.allCases, id: \.self) { sound in
                                        let isSelected = vm.selectedSound == sound
                                        Button {
                                            vm.changeSound(sound)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: soundIcon(for: sound))
                                                    .font(.system(size: 11))
                                                Text(sound.rawValue)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 9)
                                            .background(
                                                isSelected
                                                ? AnyShapeStyle(LinearGradient(
                                                        colors: [.nestPink, .nestPurple],
                                                        startPoint: .leading, endPoint: .trailing))
                                                : AnyShapeStyle(Color(.systemBackground))
                                            )
                                            .foregroundColor(isSelected ? .white : .nestDark)
                                            .cornerRadius(20)
                                            .shadow(color: isSelected
                                                    ? Color.nestPurple.opacity(0.25) : Color.clear,
                                                    radius: 4, x: 0, y: 2)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 4)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.nestPurple.opacity(0.06), radius: 6, x: 0, y: 3)
                        .padding(.horizontal)

                        // MARK: - Controls
                        HStack(spacing: 36) {

                            // Reset
                            CircleControlButton(
                                icon: "arrow.counterclockwise",
                                background: Color.nestLightPurple,
                                foreground: .nestPurple,
                                size: 54
                            ) { vm.reset() }

                            // Play / Pause (large centre button)
                            Button(action: { vm.isRunning ? vm.pause() : vm.start() }) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: vm.isOnBreak
                                                    ? [.green, .teal]
                                                    : [.nestPink, .nestPurple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 80, height: 80)
                                        .shadow(color: (vm.isOnBreak ? Color.green : Color.nestPink).opacity(0.4),
                                                radius: 14, x: 0, y: 6)

                                    Image(systemName: vm.isRunning ? "pause.fill" : "play.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                        .offset(x: vm.isRunning ? 0 : 2)
                                }
                            }
                            .scaleEffect(vm.isRunning ? 1.0 : 1.02)
                            .animation(.spring(response: 0.3), value: vm.isRunning)

                            // Skip
                            CircleControlButton(
                                icon: "forward.fill",
                                background: Color.nestLightPink,
                                foreground: .nestPink,
                                size: 54
                            ) { vm.skipPhase() }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 32)
                    }
                    .padding(.vertical, 20)
                }

                // MARK: - Phase End Banner Overlay
                if showPhaseBanner {
                    PhaseBanner(phase: vm.lastCompletedPhase) {
                        withAnimation { showPhaseBanner = false }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                }
            }
            .navigationTitle("Focus Timer")
            .navigationBarTitleDisplayMode(.large)
            // Show banner whenever phaseJustEnded flips
            .onChange(of: vm.phaseJustEnded) { ended in
                if ended {
                    withAnimation(.spring()) { showPhaseBanner = true }
                    vm.phaseJustEnded = false
                    // Auto-hide after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { showPhaseBanner = false }
                    }
                }
            }
            // Save record when user navigates away
            .onDisappear {
                Task {
                    await vm.saveRecord(
                        userId: AuthService.shared.currentUserId ?? ""
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private var phaseBadgeColour: Color {
        switch vm.phase {
        case .idle:                return .gray
        case .work:                return .nestPurple
        case .shortBreak:          return .green
        case .longBreak:           return .teal
        }
    }

    private func soundIcon(for sound: AmbientSound) -> String {
        switch sound {
        case .rain:       return "cloud.rain.fill"
        case .cafe:       return "cup.and.saucer.fill"
        case .whiteNoise: return "waveform"
        case .none:       return "speaker.slash.fill"
        }
    }
}

// MARK: - Reusable Circle Control Button

private struct CircleControlButton: View {
    let icon: String
    let background: Color
    let foreground: Color
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(background)
                    .frame(width: size, height: size)
                Image(systemName: icon)
                    .font(.system(size: size * 0.37, weight: .medium))
                    .foregroundColor(foreground)
            }
        }
    }
}

// MARK: - Phase End Banner

private struct PhaseBanner: View {
    let phase: PomodoroPhase
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Text(phase.emoji)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase == .work ? "Work phase complete! 🎉" : "Break over — let's go!")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(phase == .work
                         ? "Take a well-earned break."
                         : "Starting next work session.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.title3)
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: phase == .work ? [.green, .teal] : [.nestPink, .nestPurple],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()
        }
    }
}
