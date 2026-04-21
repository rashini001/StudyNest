import AVFoundation
import Foundation
import Combine

enum AmbientSound: String, CaseIterable {
    case rain       = "Rain"
    case cafe       = "Cafe"
    case whiteNoise = "White Noise"
    case none       = "None"

    var fileName: String? {
        switch self {
        case .rain:       return "liecio-calming-rain-257596.mp3"
        case .cafe:       return "freesound_community-cafe-35754.mp3"
        case .whiteNoise: return "freesound_community-whitenoise-75254"
        case .none:       return nil
        }
    }
}

final class AmbientSoundService: ObservableObject {
    static let shared = AmbientSoundService()
    private var player: AVAudioPlayer?
    @Published var currentSound: AmbientSound = .none

    private init() { }

    func play(_ sound: AmbientSound) {
        guard let fileName = sound.fileName,
              let url = Bundle.main.url(forResource: fileName, withExtension: "mp3")
        else { stop(); return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1  
            player?.play()
            currentSound = sound
        } catch {
            print("Audio error: \(error)")
        }
    }

    func pause() { player?.pause() }
    func resume() { player?.play() }
    func stop() { player?.stop(); currentSound = .none }
}
