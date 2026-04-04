import Foundation
import PDFKit
import UIKit
import Combine

@MainActor
final class NotesViewModel: ObservableObject {
    @Published var notes: [PDFNote] = []
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var ocrResult: [OCRTextObservation] = []
    @Published var flashcardPairs: [(question: String, answer: String)] = []

    private let biometric = BiometricService.shared
    private let ocr = OCRService.shared
    private let pdfLocal = PDFLocalService.shared
    private let firestore = FirestoreService.shared
    private var userId: String { AuthService.shared.currentUserId ?? "" }

    func authenticate() async {
        let ok = await biometric.authenticate(reason: "Unlock your PDF Notes Vault")
        isAuthenticated = ok
        if ok { await loadNotes() }
    }

    func loadNotes() async {
        isLoading = true
        do { notes = try await firestore.fetchNotes(for: userId) }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    // Called after VisionKit scan completes (array of UIImages)
    func processScan(images: [UIImage], title: String, subject: String) async {
        isLoading = true
        do {
            let (fileName, pageCount) = try pdfLocal.saveScan(images: images, title: title)
            let note = PDFNote(
                userId: userId, title: title, subject: subject,
                localFileName: fileName, pageCount: pageCount,
                isScanned: true, uploadedAt: Date()
            )
            try await firestore.saveNote(note)
            notes.insert(note, at: 0)

            // Run OCR on all pages
            var allObs: [OCRTextObservation] = []
            for img in images {
                let obs = try await ocr.recogniseText(in: img)
                allObs.append(contentsOf: obs)
            }
            ocrResult = allObs
            flashcardPairs = OCRService.autoPairToFlashcards(allObs)
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
                userId: userId, title: title, subject: subject,
                localFileName: fileName,
                pageCount: pdfDoc?.pageCount ?? 0,
                isScanned: false, uploadedAt: Date()
            )
            try await firestore.saveNote(note)
            notes.insert(note, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteNote(_ note: PDFNote) async {
        guard let id = note.id else { return }
        pdfLocal.deletePDF(fileName: note.localFileName)
        try? await firestore.deleteNote(id: id)
        notes.removeAll { $0.id == id }
    }
}

