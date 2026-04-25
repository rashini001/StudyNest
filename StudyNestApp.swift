import SwiftUI
import FirebaseCore
import CoreData

@main
struct StudyNestApp: App {
    @StateObject private var authVM  = AuthViewModel()
    @StateObject private var syncSvc = SyncService.shared
    @State private var showSplash    = true

    private let persistence = PersistenceController.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {

                // Main content
                ZStack {
                    if showSplash {
                        SplashScreenView()
                            .transition(.opacity)
                    } else {
                        if authVM.isLoggedIn {
                            MainTabView()
                                .environmentObject(authVM)
                                .environmentObject(syncSvc)
                                .transition(.opacity)
                                .task { await SyncService.shared.sync() }
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
                
                    Task {
                        await NotificationService.shared.requestAuthorization()
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        withAnimation { showSplash = false }
                    }
                }
                .environment(\.managedObjectContext, persistence.viewContext)

                //  Offline
                OfflineBanner()
                    .animation(.easeInOut(duration: 0.3), value: syncSvc.isOnline)
            }
        }
    }
}
