import Vision
import UIKit

struct OCRTextObservation {
    let text: String
    let boundingBox: CGRect
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

    static func sortedTopToBottom(_ obs: [VNRecognizedTextObservation]) -> [OCRTextObservation] {
        obs.sorted {
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

