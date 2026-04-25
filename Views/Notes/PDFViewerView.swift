import SwiftUI
import PDFKit
import UIKit
import Vision

// PDF Viewer Screen

struct PDFViewerView: View {
    let note: PDFNote

    @State private var pdfDocument: PDFDocument?
    @State private var currentPage: Int = 0
    @State private var totalPages: Int = 0
    @State private var showAnnotationToolbar = false
    @State private var selectedTool: AnnotationTool = .highlight
    @State private var selectedColor: UIColor = .systemYellow
    @State private var showOCR = false
    @State private var ocrResult: [OCRTextObservation] = []
    @State private var flashcardPairs: [(question: String, answer: String)] = []

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
           
            if let doc = pdfDocument {
                PDFKitView(
                    document: doc,
                    selectedTool: showAnnotationToolbar ? selectedTool : .none,
                    highlightColor: selectedColor,
                    onPageChanged: { page, total in
                        currentPage = page
                        totalPages = total
                    }
                )
                .ignoresSafeArea(edges: .bottom)
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading PDF…").foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if showAnnotationToolbar {
                AnnotationToolbar(
                    selectedTool: $selectedTool,
                    selectedColor: $selectedColor,
                    onClose: { showAnnotationToolbar = false }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                
                if totalPages > 0 {
                    Text("\(currentPage + 1)/\(totalPages)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showAnnotationToolbar.toggle()
                    }
                } label: {
                    Image(systemName: showAnnotationToolbar ? "pencil.circle.fill" : "pencil.circle")
                        .foregroundColor(.nestPurple)
                }

                if note.isScanned {
                    Button {
                        Task { await extractOCR() }
                    } label: {
                        Image(systemName: "doc.text.viewfinder")
                            .foregroundColor(.nestPurple)
                    }
                }

                if let doc = pdfDocument, let data = doc.dataRepresentation() {
                    ShareLink(item: data, preview: SharePreview(note.title)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showOCR) {
            OCRResultView(observations: ocrResult, pairs: flashcardPairs)
        }
        .onAppear {
            pdfDocument = PDFLocalService.shared.loadPDF(fileName: note.localFileName)
            totalPages = pdfDocument?.pageCount ?? 0
        }
    }

    // OCR extraction

    private func extractOCR() async {
        guard let doc = pdfDocument else { return }
        var images: [UIImage] = []
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let img = renderPage(page) {
                images.append(img)
            }
        }

        var allObs: [OCRTextObservation] = []
        for img in images {
            let obs = await recogniseText(in: img)
            allObs.append(contentsOf: obs)
        }
        
        ocrResult = allObs.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        flashcardPairs = OCRService.autoPairToFlashcards(ocrResult)
        showOCR = true
    }

    private func recogniseText(in image: UIImage) async -> [OCRTextObservation] {
        guard let cgImage = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let results = (req.results as? [VNRecognizedTextObservation]) ?? []
                let obs: [OCRTextObservation] = results
                    .filter { !$0.topCandidates(1).isEmpty }
                    .map { o -> OCRTextObservation in
                        let top = o.topCandidates(1)[0]
                        return OCRTextObservation(text: top.string, boundingBox: o.boundingBox)
                    }
                continuation.resume(returning: obs)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }

    private func renderPage(_ page: PDFPage) -> UIImage? {
        let rect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { ctx in
            UIColor.white.set(); ctx.fill(rect)
            ctx.cgContext.translateBy(x: 0, y: rect.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}

// PDFKit UIViewRepresentable

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    var selectedTool: AnnotationTool
    var highlightColor: UIColor
    var onPageChanged: (Int, Int) -> Void

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        pdfView.addGestureRecognizer(tap)

        context.coordinator.pdfView = pdfView
        context.coordinator.onPageChanged = onPageChanged
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.selectedTool = selectedTool
        context.coordinator.highlightColor = highlightColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedTool: selectedTool, highlightColor: highlightColor)
    }


    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var pdfView: PDFView?
        var selectedTool: AnnotationTool
        var highlightColor: UIColor
        var onPageChanged: (Int, Int) -> Void = { _, _ in }

        init(selectedTool: AnnotationTool, highlightColor: UIColor) {
            self.selectedTool = selectedTool
            self.highlightColor = highlightColor
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = pdfView,
                  let doc = pdfView.document,
                  let currentPage = pdfView.currentPage else { return }
            let pageIndex = doc.index(for: currentPage)
            onPageChanged(pageIndex, doc.pageCount)
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let pdfView = pdfView,
                  selectedTool != .none else { return }

            let point = recognizer.location(in: pdfView)
            guard let page = pdfView.page(for: point, nearest: true) else { return }
            let pagePoint = pdfView.convert(point, to: page)

            switch selectedTool {
            case .highlight:
                addHighlight(at: pagePoint, on: page)
            case .note:
                addTextNote(at: pagePoint, on: page)
            case .freehand:
                break
            case .none:
                break
            }
        }

        private func addHighlight(at point: CGPoint, on page: PDFPage) {
           
            let highlightRect = CGRect(x: point.x - 30, y: point.y - 8, width: 60, height: 16)
            let annotation = PDFAnnotation(bounds: highlightRect, forType: .highlight, withProperties: nil)
            annotation.color = highlightColor.withAlphaComponent(0.4)
            page.addAnnotation(annotation)
        }

        private func addTextNote(at point: CGPoint, on page: PDFPage) {
            let noteRect = CGRect(x: point.x, y: point.y, width: 30, height: 30)
            let annotation = PDFAnnotation(bounds: noteRect, forType: .freeText, withProperties: nil)
            annotation.font = UIFont.systemFont(ofSize: 12)
            annotation.color = UIColor.nestYellow
            annotation.contents = "Note"
            page.addAnnotation(annotation)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}

// Annotation Toolbar

enum AnnotationTool: Equatable {
    case none, highlight, note, freehand
}

struct AnnotationToolbar: View {
    @Binding var selectedTool: AnnotationTool
    @Binding var selectedColor: UIColor
    let onClose: () -> Void

    private let highlightColors: [UIColor] = [.systemYellow, .systemGreen, .systemBlue, .systemPink, .systemOrange]

    var body: some View {
        VStack(spacing: 10) {
            // Color row
            HStack(spacing: 10) {
                ForEach(highlightColors, id: \.self) { color in
                    Button {
                        selectedColor = color
                        selectedTool = .highlight
                    } label: {
                        Circle()
                            .fill(Color(color))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                            )
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 4)

            HStack(spacing: 12) {
                AnnotationToolButton(icon: "highlighter", label: "Highlight", tool: .highlight, selected: $selectedTool)
                AnnotationToolButton(icon: "note.text.badge.plus", label: "Note", tool: .note, selected: $selectedTool)
                Spacer()
                Button(action: onClose) {
                    Label("Done", systemImage: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

struct AnnotationToolButton: View {
    let icon: String
    let label: String
    let tool: AnnotationTool
    @Binding var selected: AnnotationTool

    var isActive: Bool { selected == tool }

    var body: some View {
        Button { selected = tool } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(isActive ? .white : .nestPurple)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isActive ? Color.nestPurple : Color.nestLightPurple)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

private extension UIColor {
    static var nestYellow: UIColor { UIColor.systemYellow }
}
