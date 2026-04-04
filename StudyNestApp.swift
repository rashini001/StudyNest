import SwiftUI
import FirebaseCore

@main
struct StudyNestApp: App {
    @StateObject private var authVM = AuthViewModel()
    @State private var showSplash   = true

    init() {
        FirebaseApp.configure()
        NotificationService.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                } else {
                    if authVM.isLoggedIn {
                        MainTabView()
                            .environmentObject(authVM)
                            .transition(.opacity)
                    } else {
                        LoginView()
                            .environmentObject(authVM)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: showSplash)
            .animation(.easeInOut(duration: 0.3), value: authVM.isLoggedIn)
            .onAppear {
                // Show splash for 2.2 seconds then transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation { showSplash = false }
                }
            }
        }
    }
}
