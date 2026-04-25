
import SwiftUI

struct SessionListView: View {

    @StateObject private var vm = SessionViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showAdd = false
    @State private var showCalendar = false
    @State private var sessionToDelete: StudySession?
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.sessions.isEmpty {
                    loadingView
                } else if vm.sessions.isEmpty {
                    emptyView
                } else {
                    sessionList
                }
            }
            .navigationTitle("Study Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Calendar icon
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .foregroundColor(.nestPurple)
                            .font(.title3)
                    }
                }
                // Add icon
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(
                                LinearGradient(colors: [.nestPink, .nestPurple],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .font(.title3)
                    }
                }
            }
            // AddSession sheet
            .sheet(isPresented: $showAdd) {
                AddSessionView(vm: vm)
            }
            // Calendar sheet
            .sheet(isPresented: $showCalendar) {
                SessionCalendarView(sessions: vm.sessions)
            }
            .alert("Delete Session?", isPresented: $showDeleteAlert, presenting: sessionToDelete) { s in
                Button("Delete", role: .destructive) { Task { await vm.deleteSession(s) } }
                Button("Cancel", role: .cancel) {}
            } message: { s in
                Text("'\(s.subject)' will also be removed from your calendar.")
            }
            .overlay(successToast)
         
            .task { await vm.loadSessions() }
            .refreshable { await vm.loadSessions() }
        }
    }

    // Session List
    private var sessionList: some View {
        List {
            // In Progress
            let inProgress = vm.inProgressSessions
            if !inProgress.isEmpty {
                Section {
                    ForEach(inProgress) { session in
                        SessionRowView(session: session, badge: "In Progress", badgeColor: .green) {
                            Task { await vm.markComplete(session) }
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color(.systemBackground))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            deleteButton(for: session)
                        }
                    }
                } header: { sectionHeader("Now", icon: "circle.fill", color: .green) }
            }

            // Upcoming
            let upcoming = vm.upcomingSessions
            if !upcoming.isEmpty {
                Section {
                    ForEach(upcoming) { session in
                        SessionRowView(session: session, badge: nil, badgeColor: .nestPurple) {
                            Task { await vm.markComplete(session) }
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color(.systemBackground))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            deleteButton(for: session)
                        }
                    }
                } header: { sectionHeader("Upcoming", icon: "calendar", color: .nestPurple) }
            }

            // Completed
            let completed = vm.completedSessions
            if !completed.isEmpty {
                Section {
                    ForEach(completed) { session in
                        SessionRowView(session: session, badge: "Done", badgeColor: .gray) {}
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color(.systemBackground))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            deleteButton(for: session)
                        }
                    }
                } header: {
                    sectionHeader("Completed · \(vm.totalMinutesThisWeek) min this week",
                                  icon: "checkmark.seal.fill", color: .nestPink)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground))
    }

    private func deleteButton(for session: StudySession) -> some View {
        Button(role: .destructive) {
            sessionToDelete = session
            showDeleteAlert = true
        } label: { Label("Delete", systemImage: "trash") }
    }

    // Empty State
    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.nestPink.opacity(0.15), .nestPurple.opacity(0.15)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                Image(systemName: "timer")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient(colors: [.nestPink, .nestPurple],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            Text("No Sessions Yet")
                .font(.title2).fontWeight(.bold).foregroundColor(.nestDark)
            Text("Tap + to schedule your first study session.\nIt'll sync to Apple Calendar automatically.")
                .font(.subheadline).foregroundColor(.gray)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button { showAdd = true } label: {
                Label("Add Session", systemImage: "plus")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.nestPink, .nestPurple],
                                               startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white).cornerRadius(14)
            }
            Spacer()
        }
    }

    // Loading
    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView().scaleEffect(1.4).tint(.nestPurple)
            Text("Loading sessions…").font(.subheadline).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Toast
    @ViewBuilder
    private var successToast: some View {
        if vm.showSuccess {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.checkmark")
                    Text(vm.successMessage).font(.subheadline).fontWeight(.medium)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Color.nestPurple).foregroundColor(.white)
                .cornerRadius(24)
                .shadow(color: Color.nestPurple.opacity(0.35), radius: 12, x: 0, y: 6)
                .padding(.bottom, 32)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { vm.showSuccess = false }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundColor(color)
            Text(title).font(.caption).fontWeight(.semibold).foregroundColor(color)
        }
        .textCase(nil)
    }
}

//  Calendar Sheet View

struct SessionCalendarView: View {

    let sessions: [StudySession]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdaySymbols = ["Su","Mo","Tu","We","Th","Fr","Sa"]

    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for d in range {
            days.append(calendar.date(byAdding: .day, value: d - 1, to: firstDay))
        }
        return days
    }

    private var sessionsOnSelectedDay: [StudySession] {
        sessions.filter { calendar.isDate($0.startTime, inSameDayAs: selectedDate) }
                .sorted { $0.startTime < $1.startTime }
    }

    private func hasSession(on date: Date) -> Bool {
        sessions.contains { calendar.isDate($0.startTime, inSameDayAs: date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Month header
                    HStack {
                        Button {
                            displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.nestPurple).padding(10)
                        }
                        Spacer()
                        Text(displayedMonth.monthYearFull)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.nestDark)
                        Spacer()
                        Button {
                            displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.nestPurple).padding(10)
                        }
                    }
                    .padding(.horizontal)

                    // Weekday headers
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(weekdaySymbols, id: \.self) { d in
                            Text(d)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)

                    // Day grid
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, day in
                            if let day {
                                let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                                let isToday    = calendar.isDateInToday(day)
                                let hasSes     = hasSession(on: day)

                                Button { selectedDate = day } label: {
                                    VStack(spacing: 3) {
                                        ZStack {
                                            if isSelected {
                                                Circle()
                                                    .fill(LinearGradient(
                                                        colors: [.nestPink, .nestPurple],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                                    ))
                                                    .frame(width: 36, height: 36)
                                            } else if isToday {
                                                Circle()
                                                    .stroke(Color.nestPurple, lineWidth: 2)
                                                    .frame(width: 36, height: 36)
                                            }
                                            Text("\(calendar.component(.day, from: day))")
                                                .font(.system(size: 15,
                                                              weight: isSelected || isToday ? .bold : .regular,
                                                              design: .rounded))
                                                .foregroundColor(isSelected ? .white
                                                                 : isToday ? .nestPurple : .nestDark)
                                        }
                                        // Session dot
                                        Circle()
                                            .fill(hasSes
                                                  ? (isSelected ? Color.white : Color.nestPink)
                                                  : Color.clear)
                                            .frame(width: 5, height: 5)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear.frame(height: 46)
                            }
                        }
                    }
                    .padding(.horizontal, 8)

                    Divider().padding(.horizontal)

                    // Sessions for selected day
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(calendar.isDateInToday(selectedDate) ? "Today's Sessions"
                                 : "\(selectedDate.dayMonthDisplay) Sessions")
                                .font(.headline).fontWeight(.bold).foregroundColor(.nestDark)
                            Spacer()
                            Text("\(sessionsOnSelectedDay.count) session\(sessionsOnSelectedDay.count == 1 ? "" : "s")")
                                .font(.caption).foregroundColor(.gray)
                        }
                        .padding(.horizontal)

                        if sessionsOnSelectedDay.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 28))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("No sessions on this day")
                                    .font(.subheadline).foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ForEach(sessionsOnSelectedDay) { session in
                                CalendarSessionCard(session: session)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Session Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.nestPurple)
                }
            }
        }
    }
}

// Calendar Session Card

struct CalendarSessionCard: View {
    let session: StudySession
    var body: some View {
        HStack(spacing: 14) {
           
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [.nestPink, .nestPurple],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 4)
                .frame(minHeight: 54)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(session.subject)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(session.isCompleted ? .gray : .nestDark)
                        .strikethrough(session.isCompleted, color: .gray)
                    Spacer()
                    if session.isCompleted {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.caption2).foregroundColor(.gray)
                    Text("\(session.startTime.shortTime12) – \(session.endTime.shortTime12)")
                        .font(.caption).foregroundColor(.gray)
                    Text("· \(session.computedDuration) min")
                        .font(.caption).foregroundColor(.nestPurple)
                }
                if !session.notes.isEmpty {
                    Text(session.notes)
                        .font(.caption2).foregroundColor(.gray.opacity(0.8)).lineLimit(1)
                }
                if session.calendarEventId != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar.badge.checkmark").font(.system(size: 9))
                        Text("Synced to Apple Calendar").font(.system(size: 9))
                    }
                    .foregroundColor(.nestPurple.opacity(0.7))
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: Color.nestPurple.opacity(0.07), radius: 8, x: 0, y: 3)
    }
}

// Session Row

struct SessionRowView: View {
    let session: StudySession
    let badge: String?
    let badgeColor: Color
    let onComplete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(session.isCompleted
                          ? AnyShapeStyle(Color.gray.opacity(0.15))
                          : AnyShapeStyle(LinearGradient(
                                colors: [.nestPink.opacity(0.2), .nestPurple.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .frame(width: 44, height: 44)
                if session.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .semibold)).foregroundColor(.gray)
                } else {
                    Text(String(session.subject.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.nestPink, .nestPurple],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.subject)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(session.isCompleted ? .gray : .nestDark)
                        .strikethrough(session.isCompleted, color: .gray)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(badgeColor.opacity(0.12))
                            .foregroundColor(badgeColor).cornerRadius(8)
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.caption2).foregroundColor(.gray)
                    Text("\(session.startTime.shortTime12) – \(session.endTime.shortTime12)")
                        .font(.caption).foregroundColor(.gray)
                    Text("· \(session.computedDuration) min")
                        .font(.caption).foregroundColor(.nestPurple)
                }
                if !session.notes.isEmpty {
                    Text(session.notes)
                        .font(.caption2).foregroundColor(.gray.opacity(0.8)).lineLimit(1)
                }
                if session.calendarEventId != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar.badge.checkmark").font(.system(size: 9))
                        Text("Synced to Calendar").font(.system(size: 9))
                    }
                    .foregroundColor(.nestPurple.opacity(0.7))
                }
            }

            Spacer()

            if !session.isCompleted {
                Button(action: onComplete) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(LinearGradient(colors: [.nestPink, .nestPurple],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// Date Helpers
private extension Date {
    var shortTime12: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: self)
    }
    var monthYearFull: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: self)
    }
    var dayMonthDisplay: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: self)
    }
}
