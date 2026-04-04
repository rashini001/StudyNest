import Foundation
import Combine

enum PomodoroPhase: String {
    case idle       = "Idle"
    case work       = "Work"
    case shortBreak = "Short Break"
    case longBreak  = "Long Break"
}

@MainActor
final class PomodoroViewModel: ObservableObject {
    // MARK: - State
    @Published var phase: PomodoroPhase = .idle
    @Published var secondsRemaining: Int = 25 * 60
    @Published var cyclesCompleted: Int = 0
    @Published var isRunning: Bool = false
    @Published var subjectTag: String = "General"
    @Published var selectedSound: AmbientSound = .rain

    private var timer: AnyCancellable?
    private let soundService = AmbientSoundService.shared

    // MARK: - Computed
    var totalSeconds: Int {
        switch phase {
        case .idle, .work: return 25 * 60
        case .shortBreak:  return 5 * 60
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

    // MARK: - Controls
    func start() {
        if phase == .idle { phase = .work; secondsRemaining = totalSeconds }
        isRunning = true
        soundService.play(selectedSound)
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pause() {
        isRunning = false
        timer?.cancel()
        soundService.pause()
    }

    func reset() {
        timer?.cancel()
        phase = .idle
        secondsRemaining = 25 * 60
        cyclesCompleted = 0
        isRunning = false
        soundService.stop()
    }

    func skipPhase() { advancePhase() }

    private func tick() {
        if secondsRemaining > 0 {
            secondsRemaining -= 1
        } else {
            advancePhase()
        }
    }

    private func advancePhase() {
        timer?.cancel()
        isRunning = false
        NotificationService.shared.schedulePomodoroEnd(phase: phase.rawValue)
        switch phase {
        case .idle:
            phase = .work
        case .work:
            cyclesCompleted += 1
            phase = cyclesCompleted % 4 == 0 ? .longBreak : .shortBreak
            soundService.pause()
        case .shortBreak, .longBreak:
            phase = .work
            soundService.resume()
        }
        secondsRemaining = totalSeconds
    }

    func saveRecord(userId: String) async {
        guard cyclesCompleted > 0 else { return }
        let record = PomodoroRecord(
            userId: userId,
            cyclesCompleted: cyclesCompleted,
            totalWorkMinutes: cyclesCompleted * 25,
            subjectTag: subjectTag,
            ambientSoundUsed: selectedSound.rawValue,
            recordedAt: Date()
        )
        try? await FirestoreService.shared.savePomodoroRecord(record)
    }
}

