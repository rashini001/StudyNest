import SwiftUI
import VisionKit

struct NotesVaultView: View {
    @StateObject private var vm = NotesViewModel()
    @State private var showScanner = false
    @State private var showPicker = false
    @State private var showOCR = false

    var body: some View {
        NavigationStack {
            Group {
                if !vm.isAuthenticated {
                    VaultLockedView { Task { await vm.authenticate() } }
                } else {
                    NotesList(vm: vm, showScanner: $showScanner, showPicker: $showPicker, showOCR: $showOCR)
                }
            }
            .navigationTitle("Notes Vault")
            .toolbar {
                if vm.isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Scan Notes", systemImage: "camera.fill") {
                                showScanner = true
                            }
                            Button("Import PDF", systemImage: "doc.fill") {
                                showPicker = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            // VisionKit scanner (real device) / photo picker (simulator)
            .fullScreenCover(isPresented: $showScanner) {
                if VNDocumentCameraViewController.isSupported {
                    DocumentScannerView { images in
                        showScanner = false
                        Task {
                            await vm.processScan(
                                images: images,
                                title: "Scan \(Date().shortDisplay)",
                                subject: vm.selectedSubject == "All" ? "General" : vm.selectedSubject
                            )
                        }
                    }
                } else {
                    SimulatorImagePicker { images in
                        showScanner = false
                        Task {
                            await vm.processScan(
                                images: images,
                                title: "Scan \(Date().shortDisplay)",
                                subject: vm.selectedSubject == "All" ? "General" : vm.selectedSubject
                            )
                        }
                    }
                }
            }
            // PDF document picker
            .sheet(isPresented: $showPicker) {
                DocumentPickerView { url in
                    showPicker = false
                    Task { await vm.importPDFFromURL(url, subject: vm.selectedSubject == "All" ? "General" : vm.selectedSubject) }
                }
            }
            // OCR results sheet
            .sheet(isPresented: $showOCR) {
                OCRResultView(
                    observations: vm.ocrResult,
                    pairs: vm.flashcardPairs,
                    onSaveAsNote: { text, title in
                        Task { await vm.saveTextNote(text: text, title: title) }
                    }
                )
            }
            .alert("Error", isPresented: .constant(!vm.errorMessage.isEmpty)) {
                Button("OK") { vm.errorMessage = "" }
            } message: {
                Text(vm.errorMessage)
            }
        }
    }
}

// MARK: - Notes List with Subject Tabs

struct NotesList: View {
    @ObservedObject var vm: NotesViewModel
    @Binding var showScanner: Bool
    @Binding var showPicker: Bool
    @Binding var showOCR: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Subject tab bar
            SubjectTabBar(subjects: vm.allSubjects, selected: $vm.selectedSubject)

            if vm.isLoading {
                ProgressView("Loading notes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.filteredNotes.isEmpty {
                EmptyVaultView(showScanner: $showScanner, showPicker: $showPicker)
            } else {
                List {
                    ForEach(vm.filteredNotes) { note in
                        NavigationLink(destination: PDFViewerView(note: note)) {
                            NoteRow(note: note)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await vm.deleteNote(note) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if note.isScanned {
                                Button {
                                    Task { await vm.extractOCR(for: note) }
                                } label: {
                                    Label("Extract Text", systemImage: "doc.text.viewfinder")
                                }
                                .tint(.nestPurple)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .onChange(of: vm.ocrResult) { newValue in
            if !newValue.isEmpty {
                // slight delay so sheet bindings settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showOCR = true
                }
            }
        }
    }
}

// MARK: - Subject Tab Bar

struct SubjectTabBar: View {
    let subjects: [String]
    @Binding var selected: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(subjects, id: \.self) { subject in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selected = subject }
                    } label: {
                        Text(subject)
                            .font(.subheadline).fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selected == subject ? Color.nestPurple : Color.nestLightPurple)
                            .foregroundColor(selected == subject ? .white : .nestPurple)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
        Divider()
    }
}

// MARK: - Note Row

struct NoteRow: View {
    let note: PDFNote

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(note.isScanned ? Color.nestLightPink : Color.nestLightPurple)
                    .frame(width: 44, height: 44)
                Image(systemName: note.isScanned ? "camera.viewfinder" : "doc.fill")
                    .font(.system(size: 20))
                    .foregroundColor(note.isScanned ? Color.nestPink : Color.nestPurple)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(note.title)
                    .font(.headline)
                    .foregroundColor(.nestDark)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Label(note.subject, systemImage: "folder.fill")
                        .font(.caption)
                        .foregroundColor(.nestPurple)
                    Text("·")
                        .foregroundColor(.gray)
                    Text("\(note.pageCount) \(note.pageCount == 1 ? "page" : "pages")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text(note.uploadedAt.shortDisplay)
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.8))
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State

struct EmptyVaultView: View {
    @Binding var showScanner: Bool
    @Binding var showPicker: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.nestPurple.opacity(0.4))
            Text("No notes here")
                .font(.title3).bold()
                .foregroundColor(.nestDark)
            Text("Scan handwritten notes or import a PDF to get started.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)
            HStack(spacing: 12) {
                Button("Scan Notes") { showScanner = true }
                    .buttonStyle(GradientButtonStyle())
                Button("Import PDF") { showPicker = true }
                    .buttonStyle(OutlineButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Vault Locked View

struct VaultLockedView: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.nestPurple.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "faceid")
                    .font(.system(size: 54, weight: .light))
                    .foregroundColor(.nestPurple)
            }

            Text("Notes Vault Locked")
                .font(.title2).bold()
                .foregroundColor(.nestDark)

            Text("Use Face ID to access your notes.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal, 32)

            Button(action: onUnlock) {
                Label("Unlock with Face ID", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Outline Button Style (add to your styles file if not already there)

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.nestPurple)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.nestPurple, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
