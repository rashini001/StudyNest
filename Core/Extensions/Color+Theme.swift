import SwiftUI

extension Color {
    // Primary brand colours
    static let nestPurple      = Color(red: 0.42, green: 0.13, blue: 0.66)  // #6B21A8
    static let nestPink        = Color(red: 0.86, green: 0.15, blue: 0.47)  // #DB2777
    static let nestLightPurple = Color(red: 0.93, green: 0.91, blue: 1.00)  // #EDE9FE
    static let nestLightPink   = Color(red: 0.99, green: 0.91, blue: 0.95)  // #FCE7F3
    static let nestDark        = Color(red: 0.12, green: 0.11, blue: 0.29)  // #1E1B4B

    // Gradient helpers
    static var nestGradient: LinearGradient {
        LinearGradient(
            colors: [.nestPurple, .nestPink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var nestSoftGradient: LinearGradient {
        LinearGradient(
            colors: [.nestLightPurple, .nestLightPink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// Reusable card modifier
struct NestCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.nestPurple.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func nestCard() -> some View {
        self.modifier(NestCardModifier())
    }
}

// Gradient button style
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.nestGradient)
            .cornerRadius(14)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

