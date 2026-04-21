import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject var authVM: AuthViewModel

    @State private var showProfile      = false
    @State private var showSessions     = false
    @State private var showFlashcards   = false
    @State private var showStudySpot    = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: - Greeting Header Card
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [.nestPink, .nestPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        // Decorative circles
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 130)
                            .offset(x: 260, y: -20)
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 90)
                            .offset(x: 300, y: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Good \(vm.timeOfDay)!")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.85))
                            Text(vm.displayName + ",")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(Date().fullDisplay)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 2)

                            // Stat pills row
                            HStack(spacing: 10) {
                                StatPill(value: "\(vm.streakDays)", label: "Day Streak", icon: "flame.fill")
                                StatPill(value: "\(vm.todayMinutes)", label: "Today", icon: "clock.fill")
                                StatPill(value: "\(vm.pendingTasks)", label: "Task Due", icon: "checklist")
                            }
                            .padding(.top, 12)
                        }
                        .padding(20)
                    }
                    .frame(height: 200)
                    .cornerRadius(22)
                    .padding(.horizontal)

                    // MARK: - Overdue Banner
                    if !vm.overdueTasks.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("\(vm.overdueTasks.count) overdue task(s) need attention")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal)
                    }

                    // MARK: - Quick Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .foregroundColor(.nestDark)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            Button { showSessions = true } label: {
                                QuickActionCard(icon: "timer", label: "Start\nSession", color: .nestPurple)
                            }
                            .buttonStyle(.plain)

                            Button { showFlashcards = true } label: {
                                QuickActionCard(icon: "brain.head.profile", label: "Smart\nFlashcards", color: .nestPink)
                            }
                            .buttonStyle(.plain)

                            Button { showStudySpot = true } label: {
                                QuickActionCard(icon: "mappin.and.ellipse", label: "Find\nStudy Spot", color: .orange)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    }

                    // MARK: - Weekly Progress
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Weekly Progress")
                                .font(.headline)
                                .foregroundColor(.nestDark)
                            Spacer()
                            Text("\(vm.weeklyHours)h total")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.nestPurple)
                        }
                        .padding(.horizontal)

                        HStack(spacing: 8) {
                            ForEach(["M","T","W","T","F","S","S"], id: \.self) { day in
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: [.nestPink, .nestPurple],
                                                startPoint: .top, endPoint: .bottom
                                            )
                                        )
                                        .frame(height: CGFloat.random(in: 20...80))
                                    Text(day)
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.nestPurple.opacity(0.08), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "book.pages.fill")
                        .foregroundStyle(
                            LinearGradient(colors: [.nestPink, .nestPurple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .font(.title3)
                }
                // ── ONLY CHANGE: opens ProfileView sheet instead of signing out ──
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                            .foregroundColor(.nestPurple)
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showSessions) {
                SessionListView()
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showFlashcards) {
                DeckListView()
            }
            .sheet(isPresented: $showStudySpot) {
                // Replace with your Study Spot view if you have one
                MapView()
                    .environmentObject(authVM)
            }
            .task { await vm.load() }
        }
    }
}

// MARK: - Supporting Components (unchanged)

struct StatPill: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.18))
        .cornerRadius(12)
    }
}

struct QuickActionCard: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.nestDark)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: color.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title2).bold().foregroundColor(.nestDark)
            Text(label).font(.caption).foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .nestCard()
    }
}
