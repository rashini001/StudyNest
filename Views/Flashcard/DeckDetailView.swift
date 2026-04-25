import SwiftUI

struct DeckDetailView: View {

    let deck: FlashcardDeck
    @ObservedObject var vm: FlashcardViewModel

    @State private var showingAddCard  = false
    @State private var showingReview   = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
        
                deckHeader
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                if vm.isLoading {
                    Spacer()
                    ProgressView("Loading cards…")
                        .tint(.nestPurple)
                    Spacer()
                } else if vm.currentCards.isEmpty {
                    emptyCardsState
                } else {
                    cardsList
                }
            }
            if !vm.currentCards.isEmpty {
                Button {
                    showingReview = true
                } label: {
                    Label("Start Review", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.nestGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.nestPurple.opacity(0.35), radius: 10, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(deck.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddCard = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundColor(.nestPurple)
                }
            }
        }
        .sheet(isPresented: $showingAddCard, onDismiss: {
            Task { await vm.loadCards(for: deck) }
        }) {
            AddFlashcardView(deck: deck, vm: vm)
        }
        .fullScreenCover(isPresented: $showingReview) {
            ReviewView(deck: deck, vm: vm)
        }
        .task {
            await vm.loadCards(for: deck)
        }
    }

    private var deckHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.nestLightPurple)
                    .frame(width: 56, height: 56)
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Color.nestGradient)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(deck.subject)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.nestPurple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.nestLightPurple)
                    .clipShape(Capsule())

                HStack(spacing: 6) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("\(vm.currentCards.count) \(vm.currentCards.count == 1 ? "card" : "cards")")
                        .font(.subheadline)
                        .foregroundColor(.nestDark)
                }
            }

            Spacer()
            let attempted = vm.currentCards.filter { $0.timesAttempted > 0 }
            if !attempted.isEmpty {
                let avg = attempted.map { $0.accuracy }.reduce(0, +) / Double(attempted.count)
                VStack(spacing: 2) {
                    Text("\(Int(avg * 100))%")
                        .font(.title3.bold())
                        .foregroundStyle(Color.nestGradient)
                    Text("avg")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.nestLightPurple)
                .cornerRadius(12)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: Color.nestPurple.opacity(0.08), radius: 8, y: 3)
    }

    // Cards List

    private var cardsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(vm.currentCards) { card in
                    CardRow(card: card)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 110)
        }
    }

    // Empty State

    private var emptyCardsState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.nestLightPurple)
                    .frame(width: 90, height: 90)
                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Color.nestGradient)
            }
            VStack(spacing: 8) {
                Text("No Cards Yet")
                    .font(.title3.bold())
                    .foregroundColor(.nestDark)
                Text("Add your first card manually\nor use Scan to Card.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showingAddCard = true
            } label: {
                Label("Add Card", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.nestGradient)
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// Card Row

struct CardRow: View {
    let card: Flashcard

    var body: some View {
        HStack(spacing: 12) {
           
            LinearGradient(colors: [.nestPink, .nestPurple], startPoint: .top, endPoint: .bottom)
                .frame(width: 4)
                .clipShape(Capsule())
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 5) {
                Text(card.question)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.nestDark)
                    .lineLimit(2)

                Text(card.answer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            if card.timesAttempted > 0 {
                VStack(spacing: 2) {
                    Text("\(Int(card.accuracy * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(accuracyColor(card.accuracy))
                    Text("\(card.timesAttempted)×")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(accuracyColor(card.accuracy).opacity(0.12))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: Color.nestPurple.opacity(0.07), radius: 6, y: 2)
    }

    private func accuracyColor(_ accuracy: Double) -> Color {
        accuracy >= 0.8 ? .nestPurple : accuracy >= 0.5 ? .orange : .nestPink
    }
}
