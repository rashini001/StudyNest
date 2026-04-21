//
//  ReviewView.swift
//  StudyNest
//
//  Themed to match the pink/purple StudyNest brand aesthetic.
//

import SwiftUI

// MARK: - ReviewView

struct ReviewView: View {

    let deck: FlashcardDeck
    @ObservedObject var vm: FlashcardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var dragOffset: CGSize   = .zero
    @State private var isFlipped: Bool      = false
    @State private var feedbackOpacity: Double = 0
    @State private var feedbackIsCorrect: Bool = true
    @State private var hasStarted           = false

    var body: some View {
        ZStack {
            // Full-bleed gradient background
            LinearGradient(
                colors: [Color.nestLightPurple, Color(.systemGroupedBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if vm.isLoading {
                loadingView
            } else if !hasStarted {
                startView
            } else if vm.reviewComplete {
                ResultsView(
                    vm: vm,
                    deckTitle: deck.title,
                    onRestart: {
                        Task { await vm.startReview(for: deck) }
                        isFlipped = false; dragOffset = .zero
                    },
                    onDismiss: { dismiss() }
                )
            } else {
                reviewSession
            }
        }
        .task {
            await vm.startReview(for: deck)
            hasStarted = true
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView().tint(.nestPurple).scaleEffect(1.3)
            Text("Loading cards…").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    // MARK: - Start Screen

    private var startView: some View {
        VStack(spacing: 28) {
            Spacer()

            // Deck icon
            ZStack {
                Circle()
                    .fill(Color.nestLightPurple)
                    .frame(width: 120, height: 120)
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(Color.nestGradient)
            }

            VStack(spacing: 8) {
                Text(deck.title)
                    .font(.title.bold())
                    .foregroundColor(.nestDark)
                Text(deck.subject)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(deck.cardCount) cards")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.nestPurple)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.nestLightPurple)
                    .clipShape(Capsule())
            }

            // Tips card
            VStack(alignment: .leading, spacing: 12) {
                tipRow(icon: "hand.draw.fill",   color: .nestPurple, text: "Swipe right = correct")
                tipRow(icon: "arrow.uturn.left",  color: .nestPink,   text: "Swipe left = retry")
                tipRow(icon: "hand.tap.fill",     color: .nestPurple, text: "Tap card to reveal answer")
            }
            .padding(18)
            .background(Color(.systemBackground))
            .cornerRadius(18)
            .shadow(color: Color.nestPurple.opacity(0.10), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 28)

            Spacer()

            Button {
                hasStarted = true
            } label: {
                Label("Start Review", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.nestGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func tipRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(color).frame(width: 22)
            Text(text).font(.subheadline).foregroundColor(.nestDark)
        }
    }

    // MARK: - Review Session

    private var reviewSession: some View {
        VStack(spacing: 0) {
            sessionHeader
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            // Gradient progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.nestLightPurple).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.nestPink, .nestPurple],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: progressWidth(in: geo.size.width), height: 6)
                        .animation(.spring(duration: 0.4), value: vm.reviewIndex)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 20)

            Spacer()

            // Feedback badge
            feedbackOverlay

            // Card
            if let card = vm.currentCard {
                flashCard(card: card)
                    .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width) / 22))
                    .gesture(
                        DragGesture()
                            .onChanged { v in dragOffset = v.translation }
                            .onEnded { v in
                                if      v.translation.width >  100 { commitJudgment(correct: true)  }
                                else if v.translation.width < -100 { commitJudgment(correct: false) }
                                else {
                                    withAnimation(.spring(duration: 0.4)) { dragOffset = .zero }
                                }
                            }
                    )
                    .onTapGesture {
                        guard !vm.showingAnswer else { return }
                        withAnimation(.easeInOut(duration: 0.4)) {
                            vm.showingAnswer = true; isFlipped = true
                        }
                    }
                    .animation(.interactiveSpring(duration: 0.2), value: dragOffset)
                    .padding(.horizontal, 24)
            }

            Spacer()

            actionButtons
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Session Header

    private var sessionHeader: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .fontWeight(.semibold)
                    .foregroundColor(.nestPurple)
                    .padding(8)
                    .background(Circle().fill(Color.nestLightPurple))
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(vm.reviewIndex + 1) of \(vm.currentCards.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.nestDark)
                Text(deck.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Score pill
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundColor(.nestPurple)
                Text("\(vm.correctCount)")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.nestPurple)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.nestLightPurple)
            .clipShape(Capsule())
        }
    }

    // MARK: - Flash Card

    private func flashCard(card: Flashcard) -> some View {
        ZStack {
            // Card base
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: Color.nestPurple.opacity(0.15), radius: 20, x: 0, y: 8)
                // Swipe colour tint
                .overlay(
                    RoundedRectangle(cornerRadius: 24).fill(
                        dragOffset.width > 60
                            ? Color.nestPurple.opacity(min(Double(dragOffset.width - 60) / 120, 0.18))
                            : dragOffset.width < -60
                                ? Color.nestPink.opacity(min(Double(-dragOffset.width - 60) / 120, 0.18))
                                : Color.clear
                    )
                )

            VStack(spacing: 16) {
                if isFlipped {
                    // Answer face
                    VStack(spacing: 14) {
                        Label("Answer", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.nestPink)

                        Text(card.answer)
                            .font(.title3.weight(.medium))
                            .foregroundColor(.nestDark)
                            .multilineTextAlignment(.center)
                            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

                        if card.timesAttempted > 0 {
                            Text("Accuracy: \(Int(card.accuracy * 100))%")
                                .font(.caption2)
                                .foregroundColor(.nestPurple)
                                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        }
                    }
                } else {
                    // Question face
                    VStack(spacing: 14) {
                        Label("Question", systemImage: "questionmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.nestPurple)

                        Text(card.question)
                            .font(.title3.weight(.medium))
                            .foregroundColor(.nestDark)
                            .multilineTextAlignment(.center)

                        if !vm.showingAnswer {
                            Text("Tap to reveal answer")
                                .font(.caption)
                                .foregroundColor(Color.nestPurple.opacity(0.5))
                        }
                    }
                }

                // Swipe hint
                if abs(dragOffset.width) > 30 {
                    HStack {
                        if dragOffset.width < -30 {
                            Image(systemName: "arrow.uturn.left.circle.fill")
                                .font(.title2).foregroundColor(.nestPink)
                                .transition(.scale.combined(with: .opacity))
                        }
                        Spacer()
                        if dragOffset.width > 30 {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2).foregroundColor(.nestPurple)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)
                    .animation(.spring(duration: 0.2), value: dragOffset.width)
                }
            }
            .padding(28)
        }
        .frame(height: 280)
    }

    // MARK: - Feedback Overlay

    private var feedbackOverlay: some View {
        Text(feedbackIsCorrect ? "✓ Correct!" : "↺ Retry")
            .font(.title2.bold())
            .foregroundColor(feedbackIsCorrect ? .nestPurple : .nestPink)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(
                    feedbackIsCorrect
                        ? Color.nestLightPurple
                        : Color.nestLightPink
                )
            )
            .opacity(feedbackOpacity)
            .animation(.easeOut(duration: 0.3), value: feedbackOpacity)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        if !vm.showingAnswer {
            Button {
                withAnimation(.easeInOut(duration: 0.4)) {
                    vm.showingAnswer = true; isFlipped = true
                }
            } label: {
                Text("Show Answer")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.nestGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        } else {
            HStack(spacing: 14) {
                // Retry
                Button { commitJudgment(correct: false) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.left.circle.fill").font(.title2)
                        Text("Retry").font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.nestPink)
                    .background(Color.nestLightPink)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.nestPink.opacity(0.3), lineWidth: 1)
                    )
                }

                // Correct
                Button { commitJudgment(correct: true) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").font(.title2)
                        Text("Correct").font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(Color.nestGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Judgment

    private func commitJudgment(correct: Bool) {
        feedbackIsCorrect = correct
        withAnimation(.easeIn(duration: 0.15))  { feedbackOpacity = 1 }
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) { feedbackOpacity = 0 }

        withAnimation(.easeIn(duration: 0.3)) {
            dragOffset = CGSize(width: correct ? 500 : -500, height: 0)
        }
        Task {
            if correct { await vm.markCorrect() } else { await vm.markRetry() }
            try? await Task.sleep(nanoseconds: 300_000_000)
            dragOffset = .zero
            isFlipped  = false
        }
    }

    private func progressWidth(in total: CGFloat) -> CGFloat {
        guard vm.currentCards.count > 0 else { return 0 }
        return total * CGFloat(vm.reviewIndex) / CGFloat(vm.currentCards.count)
    }
}

// MARK: - ResultsView

struct ResultsView: View {

    @ObservedObject var vm: FlashcardViewModel
    let deckTitle: String
    let onRestart: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                Spacer(minLength: 24)

                // Trophy icon
                ZStack {
                    Circle()
                        .fill(Color.nestLightPurple)
                        .frame(width: 120, height: 120)
                    Image(systemName: accuracyIcon)
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(
                            vm.sessionAccuracy >= 0.8
                                ? Color.nestGradient
                                : LinearGradient(colors: [.nestPink, .nestPink], startPoint: .top, endPoint: .bottom)
                        )
                }

                VStack(spacing: 8) {
                    Text("Session Complete!")
                        .font(.title.bold())
                        .foregroundColor(.nestDark)
                    Text(deckTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Accuracy ring
                ZStack {
                    Circle()
                        .stroke(Color.nestLightPurple, lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: vm.sessionAccuracy)
                        .stroke(
                            LinearGradient(
                                colors: [.nestPink, .nestPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 1.2), value: vm.sessionAccuracy)

                    VStack(spacing: 2) {
                        Text("\(Int(vm.sessionAccuracy * 100))%")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.nestGradient)
                        Text("Accuracy")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 160, height: 160)

                // Stats row
                HStack(spacing: 0) {
                    statBlock("\(vm.currentCards.count)", label: "Cards",   icon: "rectangle.stack.fill", color: .nestPurple)
                    Divider().frame(height: 50)
                    statBlock("\(vm.correctCount)",       label: "Correct", icon: "checkmark.circle.fill", color: .nestPurple)
                    Divider().frame(height: 50)
                    statBlock("\(vm.retryCount)",         label: "Retry",   icon: "arrow.uturn.left.circle.fill", color: .nestPink)
                }
                .padding(.vertical, 18)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: Color.nestPurple.opacity(0.10), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 28)

                // Motivational message
                Text(motivationalMessage)
                    .font(.subheadline)
                    .foregroundColor(.nestPurple)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Buttons
                VStack(spacing: 12) {
                    Button(action: onRestart) {
                        Label("Review Again", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.nestGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    Button(action: onDismiss) {
                        Text("Back to Decks")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.nestPurple)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }

    private var accuracyIcon: String {
        vm.sessionAccuracy >= 0.8 ? "trophy.fill" :
        vm.sessionAccuracy >= 0.5 ? "star.fill" : "arrow.clockwise.circle.fill"
    }

    private var motivationalMessage: String {
        switch vm.sessionAccuracy {
        case 0.9...:    return "Outstanding! You\'ve mastered this deck. 🎉"
        case 0.8..<0.9: return "Great work! Keep reviewing the tricky ones."
        case 0.6..<0.8: return "Good progress. Another round will strengthen your recall."
        case 0.4..<0.6: return "Keep going — every review builds the memory."
        default:        return "Don\'t give up! Repetition is the key to learning."
        }
    }

    private func statBlock(_ value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color).font(.title3)
            Text(value).font(.title2.bold()).foregroundColor(.nestDark)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
