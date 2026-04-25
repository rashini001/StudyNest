import Foundation
import Combine

enum PomodoroPhase: String {
    case idle       = "Idle"
    case work       = "Work"
    case shortBreak = "Short Break"
    case longBreak  = "Long Break"

    var emoji: String {
        switch self {
        case .idle:       return "😴"
        case .work:       return "🎯"
        case .shortBreak: return "☕️"
        case .longBreak:  return "🌿"
        }
    }

    var displayLabel: String {
        switch self {
        case .idle:       return "Ready to Focus"
        case .work:       return "Work — Stay Focused"
        case .shortBreak: return "Short Break"
        case .longBreak:  return "Long Break — Well Done!"
        }
    }
}

// ViewModel

@MainActor
final class PomodoroViewModel: ObservableObject {

    @Published var phase: PomodoroPhase    = .idle
    @Published var secondsRemaining: Int   = 25 * 60
    @Published var cyclesCompleted: Int    = 0
    @Published var isRunning: Bool         = false
    @Published var subjectTag: String      = "General"
    @Published var selectedSound: AmbientSound = .rain

    @Published var phaseJustEnded: Bool          = false
    @Published var lastCompletedPhase: PomodoroPhase = .idle

    private var timer: AnyCancellable?
    private let soundService = AmbientSoundService.shared

    var totalSeconds: Int {
        switch phase {
        case .idle, .work: return 25 * 60
        case .shortBreak:  return 5  * 60
        case .longBreak:   return 15 * 60
        }
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(secondsRemaining) / Double(totalSeconds)
    }

    var formattedTime: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    var phaseLabel: String { phase.rawValue }

    var isOnBreak: Bool { phase == .shortBreak || phase == .longBreak }

    // Controls

    func start() {
        if phase == .idle {
            phase = .work
            secondsRemaining = totalSeconds
        }
        isRunning = true
        if phase == .work { soundService.play(selectedSound) }

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pause() {
        isRunning = false
        timer?.cancel()
        soundService.pause()
    }

    func reset() {
        timer?.cancel()
        isRunning        = false
        phase            = .idle
        secondsRemaining = 25 * 60
        cyclesCompleted  = 0
        soundService.stop()
    }

    func skipPhase() { advancePhase() }

    // Timer Tick

    private func tick() {
        guard secondsRemaining > 0 else { advancePhase(); return }
        secondsRemaining -= 1
    }

    private func advancePhase() {
        timer?.cancel()
        isRunning = false
        let finishedPhase  = phase
        lastCompletedPhase = finishedPhase
        phaseJustEnded     = true
        NotificationService.shared.schedulePomodoroEnd(completedPhase: finishedPhase.rawValue)

        switch finishedPhase {
        case .idle:
            phase = .work

        case .work:
            cyclesCompleted += 1
            phase = (cyclesCompleted % 4 == 0) ? .longBreak : .shortBreak
            soundService.pause()

        case .shortBreak, .longBreak:
            phase = .work
            soundService.resume()
        }

        secondsRemaining = totalSeconds
        start()
    }

    // Ambient Sound

    func changeSound(_ sound: AmbientSound) {
        selectedSound = sound
        if isRunning && phase == .work { soundService.play(sound) }
    }

    func saveRecord(userId: String) async {
        guard cyclesCompleted > 0 else { return }

        let record = PomodoroRecord(
            userId:           userId,
            cyclesCompleted:  cyclesCompleted,
            totalWorkMinutes: cyclesCompleted * 25,
            subjectTag:       subjectTag.trimmingCharacters(in: .whitespaces).isEmpty
                                ? "General"
                                : subjectTag.trimmingCharacters(in: .whitespaces),
            ambientSoundUsed: selectedSound.rawValue,
            recordedAt:       Date()
        )

        try? await FirestoreService.shared.savePomodoroRecord(record)
    }
}
