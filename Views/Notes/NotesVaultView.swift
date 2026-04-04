import SwiftUI
import VisionKit

struct NotesVaultView: View {
    @StateObject private var vm = NotesViewModel()
    @State private var showScanner = false
    @State private var showPicker = false
    @State private var showOCR = false
    @State private var scanTitle = ""
    @State private var scanSubject = ""

    var body: some View {
        NavigationStack {
            Group {
                if !vm.isAuthenticated {
                    VaultLockedView { Task { await vm.authenticate() } }
                } else {
                    NotesList(vm: vm, showScanner: $showScanner, showOCR: $showOCR)
                }
            }
            .navigationTitle("Notes Vault")
            .toolbar {
                if vm.isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Scan Notes", systemImage: "camera.fill") { showScanner = true }
                            Button("Import PDF", systemImage: "doc.fill") { showPicker = true }
                        } label: { Image(systemName: "plus") }
                    }
                }
            }
            // VisionKit scanner (real device) / photo picker (simulator)
            .fullScreenCover(isPresented: $showScanner) {
                if VNDocumentCameraViewController.isSupported {
                    DocumentScannerView { images in
                        showScanner = false
                        Task { await vm.processScan(images: images, title: "Scan \(Date().shortDisplay)",
                                                    subject: "General") }
                    }
                } else {
                    // Simulator fallback
                    SimulatorImagePicker { images in
                        showScanner = false
                        Task { await vm.processScan(images: images, title: "Scan \(Date().shortDisplay)",
                                                    subject: "General") }
                    }
                }
            }
            .sheet(isPresented: $showOCR) {
                OCRResultView(observations: vm.ocrResult, pairs: vm.flashcardPairs)
            }
        }
    }
}

struct NotesList: View {
    @ObservedObject var vm: NotesViewModel
    @Binding var showScanner: Bool
    @Binding var showOCR: Bool

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading notes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.notes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "note.text")
                        .font(.system(size: 60))
                        .foregroundColor(.nestPurple.opacity(0.4))
                    Text("No notes yet")
                        .font(.title3).bold()
                        .foregroundColor(.nestDark)
                    Text("Scan your handwritten notes or import a PDF to get started.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    Button("Scan Notes") { showScanner = true }
                        .buttonStyle(GradientButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(vm.notes) { note in
                    NoteRow(note: note)
                }
                .listStyle(.plain)
            }
        }
    }
}

struct NoteRow: View {
    let note: PDFNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.headline)
                .foregroundColor(.nestDark)
            Text(note.subject)
                .font(.caption)
                .foregroundColor(.nestPurple)
            Text(note.uploadedAt.shortDisplay)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

struct VaultLockedView: View {
    let onUnlock: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill").font(.system(size: 72)).foregroundColor(.nestPurple)
            Text("PDF Vault Locked").font(.title2).bold()
            Text("Authenticate with Face ID or passcode to access your notes.")
                .multilineTextAlignment(.center).foregroundColor(.gray)
            Button("Unlock Vault", action: onUnlock).buttonStyle(GradientButtonStyle())
        }.padding()
    }
}
