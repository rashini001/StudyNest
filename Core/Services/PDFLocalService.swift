import Foundation
import PDFKit
import UIKit

final class PDFLocalService {
    static let shared = PDFLocalService()

    private var pdfDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("PDFs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func savePDF(data: Data, title: String) throws -> String {
        let safe = title.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(safe)_\(UUID().uuidString).pdf"
        let url = pdfDirectory.appendingPathComponent(fileName)
        try data.write(to: url)
        return fileName
    }

    func saveScan(images: [UIImage], title: String) throws -> (fileName: String, pageCount: Int) {
        let doc = PDFDocument()
        for (i, img) in images.enumerated() {
            if let page = PDFPage(image: img) { doc.insert(page, at: i) }
        }
        guard let data = doc.dataRepresentation() else {
            throw NSError(domain: "PDFLocal", code: -1)
        }
        let fileName = try savePDF(data: data, title: title)
        return (fileName, doc.pageCount)
    }

    func loadPDF(fileName: String) -> PDFDocument? {
        let url = pdfDirectory.appendingPathComponent(fileName)
        return PDFDocument(url: url)
    }

    func deletePDF(fileName: String) {
        let url = pdfDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
}

