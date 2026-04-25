import SwiftUI


enum TaskFilter: String, CaseIterable {
    case all     = "All"
    case pending = "Pending"
    case done    = "Done"
}

// TaskListView

struct TaskListView: View {
    @StateObject private var vm        = TaskViewModel()
    @State private var showAdd         = false
    @State private var taskFilter: TaskFilter = .all
    @State private var priorityFilter: TaskPriority? = nil

    var displayedTasks: [StudyTask] {
        let byStatus: [StudyTask]
        switch taskFilter {
        case .all:     byStatus = vm.tasks
        case .pending: byStatus = vm.pendingTasks
        case .done:    byStatus = vm.completedTasks
        }
        guard let p = priorityFilter else { return byStatus }
        return byStatus.filter { $0.priority == p }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Overdue banner
                if !vm.overdueTasks.isEmpty {
                    OverdueBanner(count: vm.overdueTasks.count)
                }

                // Status filter tabs
                HStack(spacing: 0) {
                    ForEach(TaskFilter.allCases, id: \.self) { f in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { taskFilter = f }
                        } label: {
                            VStack(spacing: 4) {
                                Text(f.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(taskFilter == f ? .bold : .regular)
                                    .foregroundColor(taskFilter == f ? .nestPurple : .gray)
                                Rectangle()
                                    .fill(taskFilter == f ? Color.nestPurple : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .background(Color(.systemBackground))

                Divider()

                // Priority filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        PriorityChip(label: "All", color: .nestPurple,
                                     isSelected: priorityFilter == nil) {
                            priorityFilter = nil
                        }
                        ForEach(TaskPriority.allCases, id: \.self) { p in
                            PriorityChip(label: p.rawValue, color: priorityColor(p),
                                         isSelected: priorityFilter == p) {
                                priorityFilter = priorityFilter == p ? nil : p
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color(.systemBackground))

                // Task list / empty state
                if vm.isLoading {
                    Spacer()
                    ProgressView("Loading tasks…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Spacer()
                } else if displayedTasks.isEmpty {
                    TaskEmptyState(filter: taskFilter, onAdd: { showAdd = true })
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(displayedTasks) { task in
                                TaskCard(task: task,
                                    onToggle: { Task { await vm.toggleCompletion(task) } },
                                    onDelete: { Task { await vm.deleteTask(task) } }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(Color(.systemBackground))
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                LinearGradient(
                                    colors: [.nestPurple, .nestPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: .nestPurple.opacity(0.4), radius: 6, y: 3)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddTaskView(vm: vm)
            }
            .task { await vm.loadTasks() }
        }
    }

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .green
        }
    }
}

// Overdue Banner

private struct OverdueBanner: View {
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
            Text("\(count) overdue \(count == 1 ? "task" : "tasks") — don't fall behind!")
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.red)
    }
}

// Task Card

private struct TaskCard: View {
    let task: StudyTask
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var priorityColor: Color {
        switch task.priority {
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .green
        }
    }

    var body: some View {
        HStack(spacing: 14) {

            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? Color.nestPurple : Color.gray.opacity(0.4),
                                lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if task.isCompleted {
                        Circle()
                            .fill(Color.nestPurple)
                            .frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(task.isCompleted ? .gray : .nestDark)
                    .strikethrough(task.isCompleted, color: .gray)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if !task.subject.isEmpty {
                        Label(task.subject, systemImage: "folder.fill")
                            .font(.caption)
                            .foregroundColor(.nestPurple)
                    }
                    Text("·").foregroundColor(.gray.opacity(0.5))
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(task.isOverdue ? .red : .gray)
                    Text(task.dueDate.fullDisplay)
                        .font(.caption)
                        .foregroundColor(task.isOverdue ? .red : .gray)
                }
            }

            Spacer()

            // Priority badge
            VStack(spacing: 6) {
                Text(task.priority.rawValue)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.12))
                    .foregroundColor(priorityColor)
                    .clipShape(Capsule())

                if task.isOverdue {
                    Text("OVERDUE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
       
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .fill(priorityColor)
                .frame(width: 4)
                .padding(.vertical, 12),
            alignment: .leading
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete this task?", isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// mpty State

private struct TaskEmptyState: View {
    let filter: TaskFilter
    let onAdd: () -> Void

    var icon: String {
        switch filter {
        case .all:     return "checklist"
        case .pending: return "clock"
        case .done:    return "checkmark.seal.fill"
        }
    }

    var title: String {
        switch filter {
        case .all:     return "No Tasks Yet"
        case .pending: return "All Caught Up!"
        case .done:    return "Nothing Done Yet"
        }
    }

    var message: String {
        switch filter {
        case .all:     return "Tap + to schedule your first task."
        case .pending: return "No pending tasks right now."
        case .done:    return "Finish a task to see it here."
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.nestPink.opacity(0.15))
                    .frame(width: 110, height: 110)
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.nestPurple)
            }

            Text(title)
                .font(.title3).bold()
                .foregroundColor(.nestDark)

            // Subtitle
            Text(message)
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.horizontal, 40)

            if filter == .all {
                Button(action: onAdd) {
                    Label("Add Task", systemImage: "plus")
                        .font(.headline).bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [.nestPink, .nestPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .nestPurple.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

//  Priority Chip

private struct PriorityChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? color : color.opacity(0.1))
                .foregroundColor(isSelected ? .white : color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// AddTaskView

struct AddTaskView: View {
    @ObservedObject var vm: TaskViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title    = ""
    @State private var subject  = ""
    @State private var dueDate  = Date().addingTimeInterval(3600)
    @State private var priority = TaskPriority.medium
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                       
                        ZStack {
                            LinearGradient(
                                colors: [.nestPurple, .nestPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .ignoresSafeArea(edges: .top)

                            VStack(spacing: 6) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.9))
                                Text("New Task")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Stay on top of your deadlines")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.vertical, 28)
                        }
                        .cornerRadius(20)
                        .padding(.horizontal)

                        // Details card
                        VStack(spacing: 0) {
                            TaskFormField(
                                icon: "textformat",
                                label: "Title",
                                content: {
                                    TextField("e.g. Submit assignment", text: $title)
                                        .font(.body)
                                }
                            )
                            Divider().padding(.leading, 52)
                            TaskFormField(
                                icon: "folder.fill",
                                label: "Subject",
                                content: {
                                    TextField("e.g. Mathematics", text: $subject)
                                        .font(.body)
                                }
                            )
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                        .padding(.horizontal)

                        //Schedule card
                        VStack(spacing: 0) {
                            TaskFormField(
                                icon: "calendar",
                                label: "Due Date",
                                content: {
                                    DatePicker("",
                                        selection: $dueDate,
                                        in: Date()...,
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .labelsHidden()
                                }
                            )
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                        .padding(.horizontal)

                        //Priority card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "flag.fill")
                                    .foregroundColor(.nestPurple)
                                    .frame(width: 22)
                                Text("Priority")
                                    .font(.subheadline)
                                    .foregroundColor(.nestDark)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)

                            HStack(spacing: 10) {
                                ForEach(TaskPriority.allCases, id: \.self) { p in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) { priority = p }
                                    } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: priorityIcon(p))
                                                .font(.title3)
                                                .foregroundColor(priority == p ? .white : priorityColor(p))
                                            Text(p.rawValue)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(priority == p ? .white : priorityColor(p))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            priority == p
                                                ? priorityColor(p)
                                                : priorityColor(p).opacity(0.1)
                                        )
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 14)

                            if priority == .high {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.caption)
                                        .foregroundColor(.nestPurple)
                                    Text("Will sync to Apple Calendar")
                                        .font(.caption)
                                        .foregroundColor(.nestPurple)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                        .padding(.horizontal)

                        // Notification note
                        HStack(spacing: 8) {
                            Image(systemName: "bell.fill")
                                .font(.caption)
                                .foregroundColor(.nestPurple)
                            Text("You'll get a reminder 1 hour before this task is due.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 24)

                        //  Save button
                        Button {
                            guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            isSaving = true
                            Task {
                                await vm.addTask(
                                    title:    title.trimmingCharacters(in: .whitespaces),
                                    subject:  subject.trimmingCharacters(in: .whitespaces),
                                    dueDate:  dueDate,
                                    priority: priority
                                )
                                isSaving = false
                                dismiss()
                            }
                        } label: {
                            ZStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Label("Save Task", systemImage: "checkmark")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                title.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.3)],
                                                     startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.nestPurple, .nestPink],
                                                     startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .nestPurple.opacity(0.35), radius: 8, y: 4)
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.nestPurple)
                }
            }
        }
    }

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .green
        }
    }

    private func priorityIcon(_ p: TaskPriority) -> String {
        switch p {
        case .high:   return "flame.fill"
        case .medium: return "flag.fill"
        case .low:    return "leaf.fill"
        }
    }
}

// TaskFormField helper

private struct TaskFormField<Content: View>: View {
    let icon: String
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.nestPurple)
                .frame(width: 22)
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
                content()
            }
            .padding(.vertical, 14)
            .padding(.trailing, 16)
        }
    }
}

// Filter / Priority chips

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(label, action: action)
            .font(.caption).bold()
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(isSelected ? Color.nestPurple : Color.nestLightPurple)
            .foregroundColor(isSelected ? .white : .nestPurple)
            .cornerRadius(20)
    }
}

struct TaskRow: View {
    let task: StudyTask
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .nestPurple : .gray)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : .nestDark)
                Text(task.dueDate.fullDisplay)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            Text(task.priority.rawValue)
                .font(.caption).bold()
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(task.isOverdue ? Color.red.opacity(0.15) : Color.nestLightPink)
                .foregroundColor(task.isOverdue ? .red : .nestPink)
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
}
