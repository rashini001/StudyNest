import SwiftUI

struct OCRResultView: View {
    let observations: [OCRTextObservation]
    let pairs: [(question: String, answer: String)]
    var onSaveAsNote: ((String, String) -> Void)? = nil

    @Environment(\.dismiss) var dismiss
    @StateObject private var flashcardVM = FlashcardViewModel()

    @State private var editableText: String = ""
    @State private var selectedDeckId: String? = nil

    private var selectedDeck: FlashcardDeck? {
        flashcardVM.decks.first { $0.id == selectedDeckId }
    }
    @State private var confirmedPairs: Set<Int> = []
    @State private var showSaveNoteAlert = false
    @State private var noteTitle = ""
    @State private var copiedToClipboard = false
    @State private var activeTab: OCRTab = .text

    enum OCRTab { case text, flashcards }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            
                Picker("View", selection: $activeTab) {
                    Text("Extracted Text").tag(OCRTab.text)
                    if !pairs.isEmpty {
                        Text("Flashcards (\(pairs.count))").tag(OCRTab.flashcards)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                ScrollView {
                    switch activeTab {
                    case .text:
                        textTab
                    case .flashcards:
                        flashcardsTab
                    }
                }
            }
            .navigationTitle("OCR Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
           
            .alert("Save as Note", isPresented: $showSaveNoteAlert) {
                TextField("Note title", text: $noteTitle)
                Button("Save") {
                    onSaveAsNote?(editableText, noteTitle.isEmpty ? "OCR Note" : noteTitle)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a title for the plain-text note.")
            }
            .task {
                editableText = observations.map { $0.text }.joined(separator: "\n")
                await flashcardVM.loadDecks()
                selectedDeckId = flashcardVM.decks.first?.id
                confirmedPairs = Set(0..<pairs.count)
            }
        }
    }

    // Text Tab

    private var textTab: some View {
        VStack(alignment: .leading, spacing: 16) {
          
            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = editableText
                    withAnimation { copiedToClipboard = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copiedToClipboard = false }
                    }
                } label: {
                    Label(copiedToClipboard ? "Copied!" : "Copy Text",
                          systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(copiedToClipboard ? .green : .nestPurple)

                Button {
                    noteTitle = "OCR Note \(Date().shortDisplay)"
                    showSaveNoteAlert = true
                } label: {
                    Label("Save as Note", systemImage: "square.and.arrow.down")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.nestPurple)

                Spacer()

                if !pairs.isEmpty {
                    Button {
                        activeTab = .flashcards
                    } label: {
                        Label("Flashcards", systemImage: "rectangle.on.rectangle")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.nestPurple)
                }
            }

            Divider()

            Text("Recognised Text")
                .font(.headline)
                .foregroundColor(.nestPurple)

            TextEditor(text: $editableText)
                .font(.body)
                .frame(minHeight: 300)
                .padding(10)
                .background(Color.nestLightPurple)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.nestPurple.opacity(0.2), lineWidth: 1)
                )

            if observations.isEmpty {
                Text("No text was recognised. Try scanning again with better lighting.")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding(16)
    }

    // Flashcards Tab

    private var flashcardsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if pairs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.on.rectangle.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No flashcard pairs generated")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("Try scanning a page with clear Q&A or term/definition format.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
               
                if !flashcardVM.decks.isEmpty {
                    HStack {
                        Text("Save to deck:")
                            .font(.subheadline)
                            .foregroundColor(.nestDark)
                        Picker("Deck", selection: $selectedDeckId) {
                            ForEach(flashcardVM.decks) { deck in
                                Text(deck.title).tag(deck.id as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.nestPurple)
                    }
                    .padding(.horizontal, 4)
                }

                HStack {
                    Text("\(confirmedPairs.count) of \(pairs.count) selected")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Button(confirmedPairs.count == pairs.count ? "Deselect All" : "Select All") {
                        if confirmedPairs.count == pairs.count {
                            confirmedPairs.removeAll()
                        } else {
                            confirmedPairs = Set(0..<pairs.count)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.nestPurple)
                }

                ForEach(Array(pairs.enumerated()), id: \.offset) { i, pair in
                    FlashcardPairRow(
                        pair: pair,
                        isSelected: confirmedPairs.contains(i),
                        onToggle: {
                            if confirmedPairs.contains(i) {
                                confirmedPairs.remove(i)
                            } else {
                                confirmedPairs.insert(i)
                            }
                        }
                    )
                }

                Button {
                    guard let deck = selectedDeck else { return }
                    let selected = confirmedPairs.sorted().filter { $0 < pairs.count }.map { pairs[$0] }
                    Task {
                        await flashcardVM.saveBatchCards(selected, toDeck: deck)
                        dismiss()
                    }
                } label: {
                    Label(
                        "Generate \(confirmedPairs.count) Flashcard\(confirmedPairs.count == 1 ? "" : "s")",
                        systemImage: "wand.and.stars"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(confirmedPairs.isEmpty || selectedDeck == nil)
                .padding(.top, 8)
            }
        }
        .padding(16)
    }
}

// Flashcard Pair Row

struct FlashcardPairRow: View {
    let pair: (question: String, answer: String)
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .nestPurple : .gray)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 6) {
                    Label("Question", systemImage: "questionmark.bubble.fill")
                        .font(.caption).foregroundColor(.nestPurple)
                    Text(pair.question)
                        .font(.subheadline)
                        .foregroundColor(.nestDark)

                    Label("Answer", systemImage: "checkmark.bubble.fill")
                        .font(.caption).foregroundColor(.nestPink)
                    Text(pair.answer)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.nestLightPurple : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.nestPurple.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
