import SwiftUI
import VisionKit
internal import LocalAuthentication

struct NotesVaultView: View {
    @StateObject private var vm = NotesViewModel()
    @State private var showScanner = false
    @State private var showPicker = false
    @State private var showOCR = false

    static func checkBiometricsAvailable() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        #endif
    }

    var body: some View {
        NavigationStack {
            Group {
                if !vm.isAuthenticated {
                    VaultLockedView(
                        isBiometricsAvailable: NotesVaultView.checkBiometricsAvailable(),
                        onUnlock: { Task { await vm.authenticate() } }
                    )
                } else {
                    NotesList(vm: vm, showScanner: $showScanner, showPicker: $showPicker, showOCR: $showOCR)
                }
            }
            .navigationTitle("Notes Vault")
            .toolbar {
                if vm.isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Scan Notes", systemImage: "camera.fill") { showScanner = true }
                            Button("Import PDF", systemImage: "doc.fill") { showPicker = true }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .task {
                if !vm.isAuthenticated {
                    await vm.authenticate()
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                AdaptiveDocumentScanner { images in
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
            .sheet(isPresented: $showPicker) {
                DocumentPickerView { url in
                    showPicker = false
                    Task {
                        await vm.importPDFFromURL(
                            url,
                            subject: vm.selectedSubject == "All" ? "General" : vm.selectedSubject
                        )
                    }
                }
            }
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

// Notes List with Subject Tabs

struct NotesList: View {
    @ObservedObject var vm: NotesViewModel
    @Binding var showScanner: Bool
    @Binding var showPicker: Bool
    @Binding var showOCR: Bool

    var body: some View {
        VStack(spacing: 0) {
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showOCR = true }
            }
        }
    }
}

// Subject Tab Bar

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

// Note Row

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
                    .font(.headline).foregroundColor(.nestDark).lineLimit(1)
                HStack(spacing: 6) {
                    Label(note.subject, systemImage: "folder.fill")
                        .font(.caption).foregroundColor(.nestPurple)
                    Text("·").foregroundColor(.gray)
                    Text("\(note.pageCount) \(note.pageCount == 1 ? "page" : "pages")")
                        .font(.caption).foregroundColor(.gray)
                }
                Text(note.uploadedAt.shortDisplay)
                    .font(.caption2).foregroundColor(.gray.opacity(0.8))
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// Empty State

struct EmptyVaultView: View {
    @Binding var showScanner: Bool
    @Binding var showPicker: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.nestPurple.opacity(0.4))
            Text("No notes here")
                .font(.title3).bold().foregroundColor(.nestDark)
            Text("Scan handwritten notes or import a PDF to get started.")
                .multilineTextAlignment(.center).foregroundColor(.gray).padding(.horizontal)
            HStack(spacing: 12) {
                Button("Scan Notes") { showScanner = true }.buttonStyle(GradientButtonStyle())
                Button("Import PDF") { showPicker = true }.buttonStyle(OutlineButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }
}

// Vault Locked View

struct VaultLockedView: View {
    let isBiometricsAvailable: Bool
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.nestPurple.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "faceid")
                    .font(.system(size: 58, weight: .light))
                    .foregroundColor(.nestPurple)
            }
            VStack(spacing: 10) {
                Text("Notes Vault Locked")
                    .font(.title2).bold().foregroundColor(.nestDark)
                if isBiometricsAvailable {
                    Text("Authenticate with Face ID to access your private notes.")
                        .multilineTextAlignment(.center).foregroundColor(.gray).padding(.horizontal, 40)
                } else {
                    VStack(spacing: 6) {
                        Text("Face ID is required to access this vault.")
                            .multilineTextAlignment(.center).foregroundColor(.gray).padding(.horizontal, 40)
                        Label("Simulator Mode", systemImage: "desktopcomputer")
                            .font(.caption).foregroundColor(.nestPurple)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.nestLightPurple).clipShape(Capsule())
                    }
                }
            }
            Spacer()
            VStack(spacing: 12) {
                Button(action: onUnlock) {
                    Label(
                        isBiometricsAvailable ? "Unlock with Face ID" : "Simulate Face ID unlock",
                        systemImage: "faceid"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())
                if !isBiometricsAvailable {
                    Text("On a real device this button is replaced by a Face ID prompt.")
                        .font(.caption2).foregroundColor(.gray).multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40).padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Outline Button Style

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).foregroundColor(.nestPurple)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).stroke(Color.nestPurple, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
