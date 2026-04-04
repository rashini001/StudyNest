import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var circleScale1: CGFloat = 0.3
    @State private var circleScale2: CGFloat = 0.3
    @State private var circleOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background gradient matching prototype
            LinearGradient(
                colors: [.nestPink, .nestPurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Decorative background circles (matches prototype bubbles)
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: geo.size.width * 0.75)
                        .scaleEffect(circleScale1)
                        .opacity(circleOpacity)
                        .offset(x: geo.size.width * 0.25, y: geo.size.height * 0.55)

                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: geo.size.width * 0.55)
                        .scaleEffect(circleScale2)
                        .opacity(circleOpacity)
                        .offset(x: -geo.size.width * 0.15, y: geo.size.height * 0.65)

                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: geo.size.width * 0.35)
                        .scaleEffect(circleScale2)
                        .opacity(circleOpacity)
                        .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.1)
                }
            }

            // Main content
            VStack(spacing: 0) {
                Spacer()

                // Book icon (matches prototype open book icon)
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 130, height: 130)

                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 62, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Spacer().frame(height: 32)

                // App name
                Text("StudyNest")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                Spacer().frame(height: 10)

                // Tagline
                Text("Your Smart Study Companion")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.88))
                    .opacity(subtitleOpacity)

                Spacer()

                // Bottom loading indicator
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.1)
                        .opacity(subtitleOpacity)

                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .opacity(subtitleOpacity)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear { animateIn() }
    }

    private func animateIn() {
        // Circles fade in
        withAnimation(.easeOut(duration: 0.6)) {
            circleScale1 = 1.0
            circleScale2 = 1.0
            circleOpacity = 1.0
        }
        // Logo bounces in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.2)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        // Title slides up
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            titleOffset = 0
            titleOpacity = 1.0
        }
        // Subtitle + loader fade in
        withAnimation(.easeIn(duration: 0.4).delay(0.75)) {
            subtitleOpacity = 1.0
        }
    }
}

#Preview {
    SplashScreenView()
}
