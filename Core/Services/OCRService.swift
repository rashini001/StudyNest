import Vision
import UIKit

struct OCRTextObservation {
    let text: String
    let boundingBox: CGRect  // normalised (0-1), origin at bottom-left
}

final class OCRService {
    static let shared = OCRService()

    func recogniseText(in image: UIImage) async throws -> [OCRTextObservation] {
        guard let cgImage = image.cgImage else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { continuation.resume(throwing: error); return }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let sorted = Self.sortedTopToBottom(observations)
                continuation.resume(returning: sorted)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do { try handler.perform([request]) }
            catch { continuation.resume(throwing: error) }
        }
    }

    // Sorts observations top-to-bottom (inverted Y), then left-to-right
    static func sortedTopToBottom(_ obs: [VNRecognizedTextObservation]) -> [OCRTextObservation] {
        obs.sorted {
            // VN bbox origin is bottom-left, so higher Y = higher on screen
            // We want top-of-page first, so sort by descending Y, then ascending X
            if abs($0.boundingBox.minY - $1.boundingBox.minY) > 0.01 {
                return $0.boundingBox.minY > $1.boundingBox.minY
            }
            return $0.boundingBox.minX < $1.boundingBox.minX
        }
        .compactMap { obs in
            guard let top = obs.topCandidates(1).first else { return nil }
            return OCRTextObservation(text: top.string, boundingBox: obs.boundingBox)
        }
    }

    // Auto-pairs lines: odd lines = questions, even lines = answers
    static func autoPairToFlashcards(_ observations: [OCRTextObservation]) -> [(question: String, answer: String)] {
        let lines = observations.map { $0.text }
        var pairs: [(question: String, answer: String)] = []
        var i = 0
        while i < lines.count {
            let q = lines[i]
            let a = lines[safe: i + 1] ?? "(no answer — add manually)"
            pairs.append((question: q, answer: a))
            i += 2
        }
        return pairs
    }
}

