//
//  AddFlashcardView.swift
//  StudyNest
//
//  Two-tab sheet: Manual Entry and Scan-to-Flashcard confirmation.
//

import SwiftUI
import Vision
import PhotosUI

// MARK: - AddFlashcardView

struct AddFlashcardView: View {

    let deck: FlashcardDeck
    @ObservedObject var vm: FlashcardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab  = 0         // 0 = Manual, 1 = Scan
    @State private var question     = ""
    @State private var answer       = ""
    @State private var saveSuccess  = false

    // Scan tab state
    @State private var pickerItem: PhotosPickerItem?
    @State private var isScanning   = false
    @State private var rawLines: [String] = []
    @State private var showScanConfirm   = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Mode", selection: $selectedTab) {
                    Text("Manual Entry").tag(0)
                    Text("Scan to Card").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

                Divider()

                // Tab content
                if selectedTab == 0 {
                    manualEntryTab
                } else {
                    scanTab
                }
            }
            .navigationTitle("Add to \(deck.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            // Route to scan-confirm sheet
            .sheet(isPresented: $showScanConfirm) {
                ScanConfirmView(vm: vm, deck: deck, onDismiss: { dismiss() })
            }
            .alert("Card Saved!", isPresented: $saveSuccess) {
                Button("Add Another") { question = ""; answer = "" }
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: - Manual Entry Tab

    private var manualEntryTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                cardPreview

                VStack(alignment: .leading, spacing: 8) {
                    Label("Question", systemImage: "questionmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $question)
                        .frame(minHeight: 90)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Answer", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $answer)
                        .frame(minHeight: 90)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                }

                Button {
                    Task {
                        await vm.addCard(question: question, answer: answer, toDeck: deck)
                        saveSuccess = true
                    }
                } label: {
                    if vm.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Label("Save Card", systemImage: "checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(question.isEmpty || answer.isEmpty || vm.isSaving)
                .padding(.top, 4)
            }
            .padding(18)
        }
    }

    // MARK: - Live card preview

    private var cardPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.accentColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
            VStack(spacing: 10) {
                Text(question.isEmpty ? "Question appears here…" : question)
                    .font(.body.weight(.medium))
                    .foregroundStyle(question.isEmpty ? .tertiary : .primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                if !answer.isEmpty {
                    Divider()
                    Text(answer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .frame(minHeight: 110)
        .animation(.easeInOut(duration: 0.2), value: question + answer)
    }

    // MARK: - Scan Tab

    private var scanTab: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Instructions card
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How Scan Works")
                            .font(.subheadline.weight(.semibold))
                        Text("Pick an image of your notes. Odd lines become questions, even lines become answers. You can edit, swap, or reject pairs before saving.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.07))
                )

                // Photo picker
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(
                        isScanning ? "Scanning…" : "Choose Image to Scan",
                        systemImage: isScanning ? "arrow.2.circlepath" : "doc.viewfinder"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .disabled(isScanning)
                .onChange(of: pickerItem) { _, newItem in
                    guard let newItem else { return }
                    Task { await runOCR(on: newItem) }
                }

                // Preview extracted lines
                if !rawLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted Lines (\(rawLines.count))")
                            .font(.subheadline.weight(.semibold))
                        ForEach(rawLines.indices, id: \.self) { i in
                            HStack(spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(
                                        Circle().fill(i % 2 == 0 ? Color.blue : Color.green)
                                    )
                                Text(rawLines[i])
                                    .font(.subheadline)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                    )

                    Button {
                        vm.buildScanPairs(from: rawLines)
                        showScanConfirm = true
                    } label: {
                        Label("Review \(pairCount) Pairs", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(18)
        }
    }

    private var pairCount: Int { (rawLines.count + 1) / 2 }

    // MARK: - OCR

    private func runOCR(on item: PhotosPickerItem) async {
        isScanning = true
        defer { isScanning = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else { return }

        let request  = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler  = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([request])

        let lines = (request.results as? [VNRecognizedTextObservation])?
            .compactMap { $0.topCandidates(1).first?.string }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            ?? []

        await MainActor.run { rawLines = lines }
    }
}

// MARK: - ScanConfirmView

struct ScanConfirmView: View {

    @ObservedObject var vm: FlashcardViewModel
    let deck: FlashcardDeck
    var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var editingIndex: Int? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    statsHeader
                }

                Section("Review Pairs — tap to edit") {
                    ForEach(vm.scanPairs.indices, id: \.self) { i in
                        ScanPairRow(
                            pair: $vm.scanPairs[i],
                            index: i,
                            onSwap:   { vm.swapPair(at: i) },
                            onToggle: { vm.toggleAccepted(at: i) }
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Confirm Pairs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        vm.scanPairs = []
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await vm.saveAcceptedScanPairs(toDeck: deck)
                            dismiss()
                            onDismiss?()
                        }
                    } label: {
                        if vm.isSaving {
                            ProgressView()
                        } else {
                            Text("Save \(acceptedCount)")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(acceptedCount == 0 || vm.isSaving)
                }
            }
        }
    }

    private var acceptedCount: Int { vm.scanPairs.filter { $0.accepted }.count }

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statCell(value: "\(vm.scanPairs.count)", label: "Total", color: .blue)
            Divider().frame(height: 36)
            statCell(value: "\(acceptedCount)", label: "Accepted", color: .green)
            Divider().frame(height: 36)
            statCell(value: "\(vm.scanPairs.count - acceptedCount)", label: "Rejected", color: .red)
        }
        .padding(.vertical, 6)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ScanPairRow

struct ScanPairRow: View {

    @Binding var pair: ScanPair
    let index: Int
    let onSwap: () -> Void
    let onToggle: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                // Accept / Reject toggle
                Button(action: onToggle) {
                    Image(systemName: pair.accepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(pair.accepted ? .green : .red)
                }
                .buttonStyle(.plain)

                // Pair number
                Text("#\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pair.question.isEmpty ? "(empty question)" : pair.question)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(isExpanded ? nil : 1)
                        .foregroundStyle(pair.accepted ? .primary : .secondary)
                    Text(pair.answer.isEmpty ? "(empty answer)" : pair.answer)
                        .font(.caption)
                        .lineLimit(isExpanded ? nil : 1)
                        .foregroundStyle(.secondary)
                }
                .animation(.easeInOut(duration: 0.2), value: isExpanded)

                Spacer()

                // Swap button
                Button(action: onSwap) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                // Expand/collapse
                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            // Expanded edit fields
            if isExpanded {
                VStack(spacing: 10) {
                    Divider().padding(.top, 8)
                    editField(title: "Question", text: $pair.question, icon: "questionmark.circle")
                    editField(title: "Answer",   text: $pair.answer,   icon: "checkmark.circle")
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 6)
        .opacity(pair.accepted ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: pair.accepted)
    }

    private func editField(title: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, text: text, axis: .vertical)
                .lineLimit(3...)
                .font(.subheadline)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemBackground))
                )
        }
    }
}
