import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject var authVM: AuthViewModel

    @State private var showProfile    = false
    @State private var showSessions   = false
    @State private var showFlashcards = false
    @State private var showStudySpot  = false
    @State private var showTodayPlan  = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Greeting Header Card
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [.nestPink, .nestPurple],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        Circle().fill(Color.white.opacity(0.08)).frame(width: 130)
                            .offset(x: 260, y: -20)
                        Circle().fill(Color.white.opacity(0.06)).frame(width: 90)
                            .offset(x: 300, y: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Good \(vm.timeOfDay)!")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.85))
                            Text(vm.displayName + ",")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(Date().fullDisplay)
                                .font(.caption).foregroundColor(.white.opacity(0.7))
                                .padding(.top, 2)

                            HStack(spacing: 10) {
                                StatPill(value: "\(vm.streakDays)",   label: "Day Streak", icon: "flame.fill")
                                StatPill(value: "\(vm.todayMinutes)", label: "Today",      icon: "clock.fill")
                                StatPill(value: "\(vm.pendingTasks)", label: "Task Due",   icon: "checklist")
                            }
                            .padding(.top, 12)
                        }
                        .padding(20)
                    }
                    .frame(height: 200)
                    .cornerRadius(22)
                    .padding(.horizontal)

                    // Today Plan Banner
                    Button { showTodayPlan = true } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.nestPink.opacity(0.15), .nestPurple.opacity(0.15)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(LinearGradient(
                                        colors: [.nestPink, .nestPurple],
                                        startPoint: .leading, endPoint: .trailing))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Today's Plan")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.nestDark)
                                let total = vm.todayItems.count
                                let done  = vm.todayItems.filter { $0.isCompleted }.count
                                Text(total == 0
                                     ? "Nothing scheduled yet"
                                     : "\(done)/\(total) items completed")
                                    .font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                           
                            let total    = vm.todayItems.count
                            let fraction = total > 0
                                ? Double(vm.todayItems.filter { $0.isCompleted }.count) / Double(total)
                                : 0
                            ZStack {
                                Circle().stroke(Color.gray.opacity(0.15), lineWidth: 4)
                                Circle()
                                    .trim(from: 0, to: fraction)
                                    .stroke(
                                        LinearGradient(colors: [.nestPink, .nestPurple],
                                                       startPoint: .leading, endPoint: .trailing),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 0.4), value: fraction)
                                Text("\(Int(fraction * 100))%")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.nestPurple)
                            }
                            .frame(width: 36, height: 36)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .padding(14)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.nestPurple.opacity(0.08), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)

                    // Overdue Banner
                    if !vm.overdueTasks.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("\(vm.overdueTasks.count) overdue task(s) need attention")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal)
                    }

                    // Next Session Card
                    NextSessionCard(session: vm.nextSession)
                        .padding(.horizontal)

                    //  Quick Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline).foregroundColor(.nestDark)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            Button { showSessions   = true } label: {
                                QuickActionCard(icon: "timer",             label: "Start\nSession",    color: .nestPurple)
                            }.buttonStyle(.plain)
                            Button { showFlashcards = true } label: {
                                QuickActionCard(icon: "brain.head.profile",label: "Smart\nFlashcards", color: .nestPink)
                            }.buttonStyle(.plain)
                            Button { showStudySpot  = true } label: {
                                QuickActionCard(icon: "mappin.and.ellipse",label: "Find\nStudy Spot",  color: .orange)
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    }

                    // Weekly Progress
                    WeeklyProgressChart(bars: vm.weeklyBars, weeklyHours: vm.weeklyHours)
                        .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showTodayPlan = true } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(
                                    colors: [.nestPink.opacity(0.15), .nestPurple.opacity(0.15)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 34, height: 34)
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(LinearGradient(
                                    colors: [.nestPink, .nestPurple],
                                    startPoint: .leading, endPoint: .trailing))
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.circle").foregroundColor(.nestPurple)
                    }
                }
            }
            .sheet(isPresented: $showTodayPlan)  { TodayPlanView(vm: vm).environmentObject(authVM) }
            .sheet(isPresented: $showProfile)    { ProfileView().environmentObject(authVM) }
            .sheet(isPresented: $showSessions)   { SessionListView().environmentObject(authVM) }
            .sheet(isPresented: $showFlashcards) { DeckListView() }
            .sheet(isPresented: $showStudySpot)  { MapView().environmentObject(authVM) }
            .task { await vm.load() }
        }
    }
}

// Next Session Card

struct NextSessionCard: View {
    let session: StudySession?

    private var timeUntil: String {
        guard let s = session else { return "" }
        let mins = Int(s.startTime.timeIntervalSince(Date()) / 60)
        if mins < 60  { return "in \(mins)m" }
        return "in \(mins / 60)h \(mins % 60)m"
    }

    var body: some View {
        HStack(spacing: 14) {
           
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [.nestPurple.opacity(0.15), .nestPink.opacity(0.10)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                Image(systemName: "clock.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(LinearGradient(
                        colors: [.nestPurple, .nestPink],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            if let s = session {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Next Session")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                    Text(s.subject)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.nestDark)
                        .lineLimit(1)
                    Text("\(s.startTime, style: .time) – \(s.endTime, style: .time)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(timeUntil)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(LinearGradient(
                        colors: [.nestPink.opacity(0.15), .nestPurple.opacity(0.15)],
                        startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(LinearGradient(
                        colors: [.nestPink, .nestPurple],
                        startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(10)

            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Next Session")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                    Text("No upcoming sessions")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.nestDark)
                    Text("Tap Start Session to schedule one")
                        .font(.caption).foregroundColor(.gray)
                }
                Spacer()
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.nestPurple.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// Weekly Progress Chart

struct WeeklyProgressChart: View {
    let bars: [WeeklyBarDay]
    let weeklyHours: Int
    private let maxBarHeight: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Progress")
                    .font(.headline).foregroundColor(.nestDark)
                Spacer()
                Text("\(weeklyHours)h total")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(.nestPurple)
            }

            if bars.isEmpty {
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { _ in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.12))
                                .frame(height: 40)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.10))
                                .frame(width: 12, height: 10)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(bars) { bar in
                        VStack(spacing: 6) {
                            if bar.isToday && bar.minutes > 0 {
                                Text("\(bar.minutes)m")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.nestPurple)
                            } else {
                                Text(" ").font(.system(size: 8))
                            }
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    bar.isToday
                                    ? AnyShapeStyle(LinearGradient(
                                        colors: [.nestPink, .nestPurple],
                                        startPoint: .top, endPoint: .bottom))
                                    : bar.minutes > 0
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: [.nestPink.opacity(0.6), .nestPurple.opacity(0.6)],
                                            startPoint: .top, endPoint: .bottom))
                                        : AnyShapeStyle(Color.gray.opacity(0.12))
                                )
                                .frame(height: max(6, CGFloat(bar.fraction) * maxBarHeight))
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: bar.fraction)
                            Text(bar.label)
                                .font(.system(size: 10))
                                .fontWeight(bar.isToday ? .bold : .regular)
                                .foregroundColor(bar.isToday ? .nestPurple : .gray)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.nestPurple.opacity(0.08), radius: 8, x: 0, y: 4)
            }
        }
    }
}

// Supporting components 

struct StatPill: View {
    let value: String; let label: String; let icon: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.white.opacity(0.18))
        .cornerRadius(12)
    }
}

struct QuickActionCard: View {
    let icon: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 50, height: 50)
                Image(systemName: icon).font(.system(size: 22)).foregroundColor(color)
            }
            Text(label)
                .font(.caption).fontWeight(.medium)
                .foregroundColor(.nestDark)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: color.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}

struct StatCard: View {
    let label: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title2).bold().foregroundColor(.nestDark)
            Text(label).font(.caption).foregroundColor(.gray)
        }
        .padding().frame(maxWidth: .infinity).nestCard()
    }
}
