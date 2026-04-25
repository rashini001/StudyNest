import SwiftUI

struct SplashScreenView: View {

    // MARK: - Animation state
    @State private var logoScale:        CGFloat = 0.5
    @State private var logoOpacity:      Double  = 0
    @State private var logoRotation:     Double  = -10

    @State private var ringScale:        CGFloat = 0.6
    @State private var ringOpacity:      Double  = 0

    @State private var titleOffset:      CGFloat = 28
    @State private var titleOpacity:     Double  = 0

    @State private var badgeOffset:      CGFloat = 20
    @State private var badgeOpacity:     Double  = 0

    @State private var loaderWidth:      CGFloat = 0     // 0 → 200
    @State private var loaderOpacity:    Double  = 0

    @State private var orb1Scale:        CGFloat = 0.4
    @State private var orb2Scale:        CGFloat = 0.4
    @State private var orbOpacity:       Double  = 0

    @State private var sparkleOpacity:   Double  = 0
    @State private var sparkleScale:     CGFloat = 0.4

    var body: some View {
        ZStack {

            LinearGradient(
                stops: [
                    
                    .init(color: Color(red: 0.86, green: 0.15, blue: 0.47), location: 0.00),
                    .init(color: Color(red: 0.49, green: 0.23, blue: 0.93), location: 0.55),
                    .init(color: Color(red: 0.30, green: 0.11, blue: 0.58), location: 1.00),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.13))
                        .frame(width: geo.size.width * 0.72)
                        .scaleEffect(orb1Scale)
                        .opacity(orbOpacity)
                        .position(x: geo.size.width * 0.82,
                                  y: geo.size.height * 0.72)
                        .blur(radius: 2)
                    Circle()
                        .fill(Color.white.opacity(0.09))
                        .frame(width: geo.size.width * 0.55)
                        .scaleEffect(orb2Scale)
                        .opacity(orbOpacity)
                        .position(x: geo.size.width * 0.15,
                                  y: geo.size.height * 0.78)
                        .blur(radius: 1.5)
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: geo.size.width * 0.34)
                        .scaleEffect(orb2Scale)
                        .opacity(orbOpacity)
                        .position(x: geo.size.width * 0.78,
                                  y: geo.size.height * 0.14)
                }
            }
            ParticleDots()
                .opacity(orbOpacity)
            VStack(spacing: 0) {

                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 164, height: 164)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.22), .white.opacity(0.05)],
                                center: .center, startRadius: 0, endRadius: 70
                            )
                        )
                        .frame(width: 138, height: 138)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.38), lineWidth: 1)
                        )
                        .frame(width: 112, height: 112)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.white.opacity(0.82)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .rotationEffect(.degrees(logoRotation))
                    SparkleView()
                        .offset(x: 52, y: -54)
                        .scaleEffect(sparkleScale)
                        .opacity(sparkleOpacity)
                }

                Spacer().frame(height: 36)
                Text("StudyNest")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(-0.5)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                Spacer().frame(height: 10)

                Text("Your smart study companion")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.82))
                    .offset(y: titleOffset * 0.6)
                    .opacity(titleOpacity)

                Spacer().frame(height: 20)

                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 56, height: 3)
                    .opacity(badgeOpacity)

                Spacer().frame(height: 20)

                HStack(spacing: 10) {
                    FeatureBadge(label: "Flashcards",     icon: "rectangle.stack.fill")
                    FeatureBadge(label: "Smart Sessions", icon: "timer")
                    FeatureBadge(label: "Study Spots",    icon: "mappin.circle.fill")
                }
                .offset(y: badgeOffset)
                .opacity(badgeOpacity)
                .padding(.horizontal, 28)

                Spacer()

                VStack(spacing: 12) {

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 200, height: 4)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.98, green: 0.66, blue: 0.83),
                                        Color(red: 0.77, green: 0.71, blue: 0.99),
                                    ],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: loaderWidth, height: 4)
                    }
                    .opacity(loaderOpacity)

                    Text("Loading your workspace…")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                        .opacity(loaderOpacity)
                }
                .padding(.bottom, 56)
            }

            VStack {
                Spacer()
                Text("v1.0.0")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.30))
                    .padding(.bottom, 18)
            }
        }
        .onAppear { runAnimations() }
    }

    private func runAnimations() {
        withAnimation(.easeOut(duration: 0.7)) {
            orb1Scale  = 1.0
            orb2Scale  = 1.0
            orbOpacity = 1.0
        }

        withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.15)) {
            ringScale   = 1.0
            ringOpacity = 1.0
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.60).delay(0.30)) {
            logoScale    = 1.0
            logoOpacity  = 1.0
            logoRotation = 0
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55).delay(0.65)) {
            sparkleScale   = 1.0
            sparkleOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.55)) {
            titleOffset  = 0
            titleOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.78)) {
            badgeOffset  = 0
            badgeOpacity = 1.0
        }
        withAnimation(.easeIn(duration: 0.35).delay(0.90)) {
            loaderOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 1.6).delay(1.0)) {
            loaderWidth = 200
        }
    }
}

private struct FeatureBadge: View {
    let label: String
    let icon:  String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.90))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.14))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
        )
    }
}

private struct SparkleView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.99, green: 0.91, blue: 0.54))
                .frame(width: 7, height: 7)
            Capsule()
                .fill(Color(red: 0.99, green: 0.91, blue: 0.54))
                .frame(width: 1.5, height: 12)
            Capsule()
                .fill(Color(red: 0.99, green: 0.91, blue: 0.54))
                .frame(width: 12, height: 1.5)
        }
    }
}

private struct ParticleDots: View {
    private let dots: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.32, 0.17, 3.0, 0.25),
        (0.72, 0.38, 2.5, 0.18),
        (0.28, 0.53, 2.0, 0.20),
        (0.70, 0.60, 3.5, 0.15),
        (0.38, 0.75, 2.0, 0.22),
        (0.74, 0.78, 2.5, 0.17),
        (0.22, 0.85, 3.0, 0.13),
        (0.66, 0.88, 2.0, 0.19),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(dots.indices, id: \.self) { i in
                let d = dots[i]
                Circle()
                    .fill(Color.white.opacity(d.3))
                    .frame(width: d.2, height: d.2)
                    .position(x: geo.size.width  * d.0,
                              y: geo.size.height * d.1)
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
