import SwiftUI

struct PomodoroView: View {
    @StateObject private var vm = PomodoroViewModel()
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {

                    // MARK: - Subject Tag Field
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.nestPurple)
                            .font(.caption)
                        TextField("Subject", text: $vm.subjectTag)
                            .font(.subheadline)
                            .foregroundColor(.nestDark)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // MARK: - Phase Label
                    Text(vm.phaseLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.nestPurple)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.nestLightPurple)
                        .cornerRadius(20)

                    // MARK: - Timer Ring
                    ZStack {
                        // Outer track
                        Circle()
                            .stroke(Color.nestLightPink, lineWidth: 16)
                            .frame(width: 240, height: 240)

                        // Progress arc
                        Circle()
                            .trim(from: 0, to: vm.progress)
                            .stroke(
                                LinearGradient(
                                    colors: [.nestPink, .nestPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 16, lineCap: .round)
                            )
                            .frame(width: 240, height: 240)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: vm.progress)

                        // Time display
                        VStack(spacing: 4) {
                            Text(vm.formattedTime)
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundColor(.nestDark)
                            Text(vm.isRunning ? "In Progress" : "Ready")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    // MARK: - Cycle Dots
                    HStack(spacing: 10) {
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill(i < vm.cyclesCompleted % 4
                                      ? AnyShapeStyle(LinearGradient(colors: [.nestPink, .nestPurple],
                                                                      startPoint: .leading, endPoint: .trailing))
                                      : AnyShapeStyle(Color.nestLightPurple))
                                .frame(width: 14, height: 14)
                                .animation(.spring(), value: vm.cyclesCompleted)
                        }
                    }

                    // MARK: - Ambient Sound
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ambient Sound")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(AmbientSound.allCases, id: \.self) { sound in
                                    let isSelected = vm.selectedSound == sound
                                    Button {
                                        vm.selectedSound = sound
                                    } label: {
                                        Text(sound.rawValue)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                isSelected
                                                ? AnyShapeStyle(LinearGradient(colors: [.nestPink, .nestPurple],
                                                                                startPoint: .leading, endPoint: .trailing))
                                                : AnyShapeStyle(Color(.systemGray6))
                                            )
                                            .foregroundColor(isSelected ? .white : .nestDark)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // MARK: - Controls
                    HStack(spacing: 32) {
                        // Reset
                        Button(action: vm.reset) {
                            ZStack {
                                Circle()
                                    .fill(Color.nestLightPurple)
                                    .frame(width: 54, height: 54)
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.nestPurple)
                            }
                        }

                        // Play / Pause
                        Button(action: { vm.isRunning ? vm.pause() : vm.start() }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.nestPink, .nestPurple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 76, height: 76)
                                    .shadow(color: .nestPink.opacity(0.4), radius: 12, x: 0, y: 6)
                                Image(systemName: vm.isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .offset(x: vm.isRunning ? 0 : 2)
                            }
                        }
                        .scaleEffect(vm.isRunning ? 1.0 : 1.0)
                        .animation(.spring(response: 0.3), value: vm.isRunning)

                        // Skip
                        Button(action: vm.skipPhase) {
                            ZStack {
                                Circle()
                                    .fill(Color.nestLightPink)
                                    .frame(width: 54, height: 54)
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.nestPink)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Focus Timer")
            .navigationBarTitleDisplayMode(.large)
            .onDisappear {
                Task { await vm.saveRecord(userId: AuthService.shared.currentUserId ?? "") }
            }
        }
    }
}
