//
//  DeckListView.swift
//  StudyNest
//
//  Themed to match the pink/purple StudyNest brand aesthetic.
//

import SwiftUI

struct DeckListView: View {

    @StateObject private var vm = FlashcardViewModel()

    @State private var showingCreateDeck  = false
    @State private var showingScanConfirm = false
    @State private var selectedDeck: FlashcardDeck?

    @State private var newTitle   = ""
    @State private var newSubject = ""

    var initialScanLines: [String] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if vm.isLoading {
                    loadingView
                } else if vm.decks.isEmpty {
                    emptyState
                } else {
                    deckList
                }
            }
            .navigationTitle("My Decks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .task { await vm.loadDecks() }
            .onAppear {
                if !initialScanLines.isEmpty {
                    vm.buildScanPairs(from: initialScanLines)
                    showingScanConfirm = true
                }
            }
            .sheet(isPresented: $showingCreateDeck) { createDeckSheet }
            .sheet(isPresented: $showingScanConfirm) {
                if let deck = selectedDeck {
                    ScanConfirmView(vm: vm, deck: deck)
                }
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.nestPurple)
                .scaleEffect(1.4)
            Text("Loading decks…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Deck List

    private var deckList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(vm.decks) { deck in
                    // NavigationLink → DeckDetailView on tap
                    NavigationLink(destination: DeckDetailView(deck: deck, vm: vm)) {
                        DeckCard(deck: deck)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            selectedDeck = deck
                        } label: {
                            Label("View Deck", systemImage: "rectangle.stack")
                        }
                        Divider()
                        Button(role: .destructive) {
                            Task { await vm.deleteDeck(deck) }
                        } label: {
                            Label("Delete Deck", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await vm.deleteDeck(deck) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.nestLightPurple)
                    .frame(width: 100, height: 100)
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(Color.nestGradient)
            }
            VStack(spacing: 8) {
                Text("No Decks Yet")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.nestDark)
                Text("Create your first deck and start\nadding flashcards.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showingCreateDeck = true
            } label: {
                Label("Create Deck", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.nestGradient)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingCreateDeck = true
            } label: {
                Image(systemName: "plus")
                    .fontWeight(.semibold)
                    .foregroundColor(.nestPurple)
            }
        }
    }

    // MARK: - Create Deck Sheet

    private var createDeckSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Deck Title", text: $newTitle)
                    TextField("Subject (e.g. Biology)", text: $newSubject)
                } header: {
                    Text("Deck Info")
                        .foregroundColor(.nestPurple)
                        .fontWeight(.semibold)
                }
            }
            .navigationTitle("New Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCreateDeck = false
                        newTitle = ""; newSubject = ""
                    }
                    .foregroundColor(.nestPurple)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard !newTitle.isEmpty else { return }
                        Task {
                            await vm.createDeck(title: newTitle, subject: newSubject)
                            newTitle = ""; newSubject = ""
                            showingCreateDeck = false
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(newTitle.isEmpty ? .gray : .nestPurple)
                    .disabled(newTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - DeckCard

struct DeckCard: View {
    let deck: FlashcardDeck

    private var subjectColor: Color {
        switch deck.subject.lowercased() {
        case let s where s.contains("math"):  return .blue
        case let s where s.contains("bio"):   return .green
        case let s where s.contains("chem"):  return .orange
        case let s where s.contains("phys"):  return .purple
        case let s where s.contains("hist"):  return .brown
        case let s where s.contains("lang"):  return .nestPink
        default:                              return .nestPurple
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Left gradient accent bar
            LinearGradient(
                colors: [.nestPink, .nestPurple],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 5)
            .clipShape(Capsule())
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(deck.title)
                    .font(.headline)
                    .foregroundColor(.nestDark)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label(deck.subject, systemImage: "tag.fill")
                        .font(.caption)
                        .foregroundStyle(subjectColor)
                    Spacer()
                    Label("\(deck.cardCount) cards", systemImage: "rectangle.stack.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.nestPurple.opacity(0.10), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    DeckListView()
}
