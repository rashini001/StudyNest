import Foundation
import PDFKit
import UIKit
import Vision
import Combine

@MainActor
final class NotesViewModel: ObservableObject {
    @Published var notes: [PDFNote] = []
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var ocrResult: [OCRTextObservation] = []
    @Published var flashcardPairs: [(question: String, answer: String)] = []

    @Published var selectedSubject: String = "All"

    var allSubjects: [String] {
        let subjects = Set(notes.map { $0.subject }).sorted()
        return ["All"] + subjects
    }

    var filteredNotes: [PDFNote] {
        if selectedSubject == "All" { return notes }
        return notes.filter { $0.subject == selectedSubject }
    }

    private let biometric = BiometricService.shared
    private let pdfLocal = PDFLocalService.shared
    private let firestore = FirestoreService.shared
    private var userId: String { AuthService.shared.currentUserId ?? "" }

    //Auth

    func authenticate() async {
        let ok = await biometric.authenticate(reason: "Unlock your PDF Notes Vault")
        isAuthenticated = ok
        if ok { await loadNotes() }
    }

    //Load

    func loadNotes() async {
        isLoading = true
        do {
            notes = try await firestore.fetchNotes(for: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    //Scan (VisionKit)

    func processScan(images: [UIImage], title: String, subject: String) async {
        isLoading = true
        do {
            let (fileName, pageCount) = try pdfLocal.saveScan(images: images, title: title)
            let note = PDFNote(
                userId: userId,
                title: title,
                subject: subject,
                localFileName: fileName,
                pageCount: pageCount,
                isScanned: true,
                uploadedAt: Date()
            )
            try await firestore.saveNote(note)
            notes.insert(note, at: 0)

            await runOCR(on: images)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    //Import PDF from URL

    func importPDFFromURL(_ url: URL, subject: String) async {
        isLoading = true
        do {
            // Security-scoped access for Files app URLs
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let title = url.deletingPathExtension().lastPathComponent
            let fileName = try pdfLocal.savePDF(data: data, title: title)
            let pdfDoc = PDFDocument(data: data)

            let note = PDFNote(
                userId: userId,
                title: title,
                subject: subject,
                localFileName: fileName,
                pageCount: pdfDoc?.pageCount ?? 0,
                isScanned: false,
                uploadedAt: Date()
            )
            try await firestore.saveNote(note)
            notes.insert(note, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func importPDF(data: Data, title: String, subject: String) async {
        isLoading = true
        do {
            let fileName = try pdfLocal.savePDF(data: data, title: title)
            let pdfDoc = PDFDocument(data: data)
            let note = PDFNote(
                userId: userId,
                title: title,
                subject: subject,
                localFileName: fileName,
                pageCount: pdfDoc?.pageCount ?? 0,
                isScanned: false,
                uploadedAt: Date()
            )
            try await firestore.saveNote(note)
            notes.insert(note, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    //Delete

    func deleteNote(_ note: PDFNote) async {
        guard let id = note.id else { return }
        pdfLocal.deletePDF(fileName: note.localFileName)
        try? await firestore.deleteNote(id: id)
        notes.removeAll { $0.id == id }
    }

    //OCR

    func extractOCR(for note: PDFNote) async {
        guard let pdfDoc = pdfLocal.loadPDF(fileName: note.localFileName) else {
            errorMessage = "Could not load PDF for OCR."
            return
        }
        isLoading = true
        var images: [UIImage] = []
        for i in 0..<pdfDoc.pageCount {
            if let page = pdfDoc.page(at: i),
               let img = renderPDFPage(page) {
                images.append(img)
            }
        }
        await runOCR(on: images)
        isLoading = false
    }

    //Internal OCR runner

    private func runOCR(on images: [UIImage]) async {
        var allObs: [OCRTextObservation] = []
        for img in images {
            let obs = await recogniseTextAccurate(in: img)
            allObs.append(contentsOf: obs)
        }
        ocrResult = allObs.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        flashcardPairs = OCRService.autoPairToFlashcards(ocrResult)
    }

    private func recogniseTextAccurate(in image: UIImage) async -> [OCRTextObservation] {
        guard let cgImage = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let results = request.results as? [VNRecognizedTextObservation] ?? []
                let observations: [OCRTextObservation] = results
                    .filter { !$0.topCandidates(1).isEmpty }
                    .map { obs -> OCRTextObservation in
                        let candidate = obs.topCandidates(1)[0]
                        return OCRTextObservation(
                            text: candidate.string,
                            boundingBox: obs.boundingBox
                        )
                    }
                continuation.resume(returning: observations)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    //Save plain-text note from OCR

    func saveTextNote(text: String, title: String) async {
        isLoading = true
        do {
            let textData = text.data(using: .utf8) ?? Data()
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
            let pdfData = renderer.pdfData { ctx in
                ctx.beginPage()
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.black
                ]
                let margin: CGFloat = 40
                let rect = CGRect(x: margin, y: margin, width: 612 - margin * 2, height: 792 - margin * 2)
                text.draw(in: rect, withAttributes: attrs)
            }
            let fileName = try pdfLocal.savePDF(data: pdfData, title: title)
            let note = PDFNote(
                userId: userId,
                title: title,
                subject: selectedSubject == "All" ? "General" : selectedSubject,
                localFileName: fileName,
                pageCount: 1,
                isScanned: false,
                uploadedAt: Date()
            )
            try await firestore.saveNote(note)
            notes.insert(note, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    //Helpers

    private func renderPDFPage(_ page: PDFPage) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            ctx.cgContext.translateBy(x: 0, y: pageRect.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}

extension OCRTextObservation: Equatable {
    static func == (lhs: OCRTextObservation, rhs: OCRTextObservation) -> Bool {
        lhs.text == rhs.text && lhs.boundingBox == rhs.boundingBox
    }
}
