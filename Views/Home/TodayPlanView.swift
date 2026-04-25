import SwiftUI

// Unified timeline item

enum TodayItem: Identifiable {
    case session(StudySession)
    case task(StudyTask)
    case pomodoro(PomodoroRecord)

    var id: String {
        switch self {
        case .session(let s):   return "s-\(s.id ?? UUID().uuidString)"
        case .task(let t):      return "t-\(t.id ?? UUID().uuidString)"
        case .pomodoro(let p):  return "p-\(p.id ?? UUID().uuidString)"
        }
    }

    var sortTime: Date {
        switch self {
        case .session(let s):   return s.startTime
        case .task(let t):      return t.dueDate
        case .pomodoro(let p):  return p.recordedAt
        }
    }

    var isCompleted: Bool {
        switch self {
        case .session(let s):   return s.isCompleted
        case .task(let t):      return t.isCompleted
        case .pomodoro:         return true
        }
    }
}

// Main view

struct TodayPlanView: View {

    @ObservedObject var vm: HomeViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerBanner
                        progressSummary
                        timelineContent
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.nestPurple)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await vm.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.nestPurple)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
        }
    }

    // Header Banner

    private var headerBanner: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [.nestPink, .nestPurple],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle().fill(Color.white.opacity(0.07)).frame(width: 140).offset(x: 270, y: -10)
            Circle().fill(Color.white.opacity(0.05)).frame(width: 90).offset(x: 310, y: 30)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    Text("Today's Plan")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                Text(Date().todayPlanDateDisplay)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                let total     = vm.todayItems.count
                let completed = vm.todayItems.filter { $0.isCompleted }.count
                let fraction  = total > 0 ? Double(completed) / Double(total) : 0

                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.25))
                            Capsule()
                                .fill(Color.white)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                    .frame(height: 6)
                    Text("\(completed)/\(total) done")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.top, 6)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }

    // Progress Summary Pills

    private var progressSummary: some View {
        let sessions  = vm.todaySessions
        let tasks     = vm.todayTasks
        let doneSes   = sessions.filter  { $0.isCompleted }.count
        let doneTasks = tasks.filter     { $0.isCompleted }.count

        return HStack(spacing: 10) {
            SummaryPill(
                icon:  "timer",
                value: "\(doneSes)/\(sessions.count)",
                label: "Sessions",
                color: .nestPurple
            )
            SummaryPill(
                icon:  "checklist",
                value: "\(doneTasks)/\(tasks.count)",
                label: "Tasks",
                color: .nestPink
            )
            SummaryPill(
                icon:  "clock.fill",
                value: "\(vm.todayMinutes) min",
                label: "Studied",
                color: .orange
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
    }

    // Timeline Content

    @ViewBuilder
    private var timelineContent: some View {
        if vm.todayItems.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Timeline")
                        .font(.headline).fontWeight(.bold)
                        .foregroundColor(.nestDark)
                    Spacer()
                    Text("\(vm.todayItems.count) item\(vm.todayItems.count == 1 ? "" : "s")")
                        .font(.caption).foregroundColor(.gray)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

                // Timeline rows
                ForEach(Array(vm.todayItems.enumerated()), id: \.element.id) { idx, item in
                    HStack(alignment: .top, spacing: 0) {

                     
                        VStack(spacing: 0) {
                            Text(item.sortTime.shortTime12)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.gray)
                                .frame(width: 48, alignment: .trailing)
                                .padding(.top, 14)

                            ZStack {
                                Circle()
                                    .fill(item.isCompleted ? Color.green : dotColor(item))
                                    .frame(width: 12, height: 12)
                                if item.isCompleted {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 6, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.top, 4)
                            if idx < vm.todayItems.count - 1 {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 1.5)
                                    .frame(maxHeight: .infinity)
                                    .padding(.top, 4)
                            }
                        }
                        .frame(width: 68)
                        Group {
                            switch item {
                            case .session(let s):
                                SessionPlanCard(session: s) {
                                    Task { await vm.markSessionComplete(s) }
                                }
                            case .task(let t):
                                TaskPlanCard(task: t) {
                                    Task { await vm.toggleTaskComplete(t) }
                                }
                            case .pomodoro(let p):
                                PomodoroPlanCard(record: p)
                            }
                        }
                        .padding(.trailing, 18)
                        .padding(.bottom, 14)
                    }
                    .padding(.leading, 14)
                }
            }
        }
    }

    // Empty State

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.nestPink.opacity(0.15), .nestPurple.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 90, height: 90)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(LinearGradient(
                        colors: [.nestPink, .nestPurple],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            Text("Nothing Planned Today")
                .font(.title3).fontWeight(.bold).foregroundColor(.nestDark)
            Text("Add sessions or tasks and they'll\nappear here automatically.")
                .font(.subheadline).foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
    private func dotColor(_ item: TodayItem) -> Color {
        switch item {
        case .session:  return .nestPurple
        case .task(let t): return t.isOverdue ? .red : .nestPink
        case .pomodoro: return .orange
        }
    }
}

// Summary Pill

struct SummaryPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.nestDark)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.07))
        .cornerRadius(12)
    }
}

// Session Plan Card

struct SessionPlanCard: View {
    let session: StudySession
    let onComplete: () -> Void

    private var progress: Double {
        guard !session.isCompleted else { return 1.0 }
        let now = Date()
        guard session.startTime < now else { return 0 }
        let total    = session.endTime.timeIntervalSince(session.startTime)
        let elapsed  = now.timeIntervalSince(session.startTime)
        return min(1.0, max(0, elapsed / max(1, total)))
    }

    private var statusLabel: String {
        if session.isCompleted { return "Complete" }
        if session.startTime > Date() { return "Upcoming" }
        if session.endTime > Date()   { return "In Progress" }
        return "Missed"
    }

    private var statusColor: Color {
        if session.isCompleted { return .green }
        if session.startTime > Date() { return .nestPurple }
        if session.endTime > Date()   { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.subject)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(session.isCompleted ? .gray : .nestDark)
                        .strikethrough(session.isCompleted, color: .gray)

                    Text("\(session.startTime.shortTime12) – \(session.endTime.shortTime12)  ·  \(session.computedDuration / 60)h \(session.computedDuration % 60)m")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text(statusLabel)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [.nestPink, .nestPurple],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 5)

            HStack(spacing: 6) {
                if session.calendarEventId != nil {
                    tagPill("Reminder Set", icon: "bell.fill", color: .nestPurple)
                }
                if !session.notes.isEmpty {
                    tagPill("Has Notes", icon: "note.text", color: .nestPink)
                }
                Spacer()
               
                if !session.isCompleted {
                    Button(action: onComplete) {
                        Label("Mark Done", systemImage: "checkmark.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.nestPurple)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: Color.nestPurple.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private func tagPill(_ label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9))
            Text(label).font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.10))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}

// Task Plan Card

struct TaskPlanCard: View {
    let task: StudyTask
    let onToggle: () -> Void

    private var priorityColor: Color {
        switch task.priority {
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .green
        }
    }

    var body: some View {
        HStack(spacing: 12) {
         
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? Color.green : priorityColor, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if task.isCompleted {
                        Circle().fill(Color.green).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(task.isCompleted ? .gray : .nestDark)
                    .strikethrough(task.isCompleted, color: .gray)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if !task.subject.isEmpty {
                        Label(task.subject, systemImage: "tag.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.nestPurple)
                    }
                    if task.isOverdue {
                        Label("Overdue", systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.red)
                    }
                }
            }

            Spacer()

            Text(task.priority.rawValue.capitalized)
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(priorityColor.opacity(0.12))
                .foregroundColor(priorityColor)
                .cornerRadius(6)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(task.isOverdue && !task.isCompleted
                        ? Color.red.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .shadow(color: Color.nestPink.opacity(0.07), radius: 6, x: 0, y: 3)
    }
}

// Pomodoro Plan Card

struct PomodoroPlanCard: View {
    let record: PomodoroRecord
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "timer")
                    .font(.system(size: 15))
                    .foregroundColor(.orange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Pomodoro · \(record.subjectTag.isEmpty ? "General" : record.subjectTag)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.nestDark)
                Text("\(record.cyclesCompleted) cycles · \(record.totalWorkMinutes) min")
                    .font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Label("Done", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.green)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: Color.orange.opacity(0.07), radius: 6, x: 0, y: 3)
    }
}


private extension Date {
    var todayPlanDateDisplay: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: self)
    }
    var shortTime12: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: self)
    }
}
