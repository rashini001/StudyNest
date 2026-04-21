//
//  StudyNestApp.swift
//  StudyNest
//

import SwiftUI
import FirebaseCore
import CoreData

@main
struct StudyNestApp: App {
    @StateObject private var authVM  = AuthViewModel()
    @StateObject private var syncSvc = SyncService.shared
    @State private var showSplash    = true

    // Core Data persistent container
    private let persistence = PersistenceController.shared

    init() {
        FirebaseApp.configure()
        NotificationService.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {

                // ── Main content ──────────────────────────────────
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
                                // Trigger first sync once user is logged in
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        withAnimation { showSplash = false }
                    }
                }
                // Inject Core Data context into the entire view hierarchy
                .environment(
                    \.managedObjectContext,
                     persistence.viewContext
                )

                // ── Offline / syncing banner (top overlay) ────────
                OfflineBanner()
                    .animation(.easeInOut(duration: 0.3), value: syncSvc.isOnline)

            }
        }
    }
}
