import SwiftUI

struct OCRResultView: View {
    let observations: [OCRTextObservation]
    let pairs: [(question: String, answer: String)]
    @Environment(\.dismiss) var dismiss
    @StateObject private var flashcardVM = FlashcardViewModel()
    @State private var selectedDeck: FlashcardDeck?
    @State private var confirmedPairs: Set<Int> = []

    var ocrText: String { observations.map { $0.text }.joined(separator: "\n") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Extracted Text").font(.headline).foregroundColor(.nestPurple)
                    Text(ocrText).font(.body).padding().background(Color.nestLightPurple)
                        .cornerRadius(12)

                    if !pairs.isEmpty {
                        Text("Auto-Generated Flashcard Pairs").font(.headline).foregroundColor(.nestPurple)
                        ForEach(Array(pairs.enumerated()), id: \.offset) { i, pair in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Q: \(pair.question)").bold()
                                Text("A: \(pair.answer)").foregroundColor(.gray)
                                Toggle("Include", isOn: Binding(
                                    get: { confirmedPairs.contains(i) },
                                    set: { if $0 { confirmedPairs.insert(i) } else { confirmedPairs.remove(i) } }
                                ))
                            }
                            .padding().background(Color.nestLightPink).cornerRadius(12)
                        }

                        if let deck = selectedDeck {
                            Button("Save \(confirmedPairs.count) Cards to '\(deck.title)'") {
                                let selected = confirmedPairs.compactMap { pairs[safe: $0] }
                                Task {
                                    await flashcardVM.saveBatchCards(selected, toDeck: deck)
                                    dismiss()
                                }
                            }.buttonStyle(GradientButtonStyle()).disabled(confirmedPairs.isEmpty)
                        }
                    }
                }.padding()
            }
            .navigationTitle("OCR Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task {
                await flashcardVM.loadDecks()
                selectedDeck = flashcardVM.decks.first
                confirmedPairs = Set(0..<pairs.count)
            }
        }
    }
}

