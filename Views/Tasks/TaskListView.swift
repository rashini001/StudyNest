import SwiftUI

struct TaskListView: View {
    @StateObject private var vm = TaskViewModel()
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Priority filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "All", isSelected: vm.filterPriority == nil) {
                            vm.filterPriority = nil
                        }
                        ForEach(TaskPriority.allCases, id: \.self) { p in
                            FilterChip(label: p.rawValue, isSelected: vm.filterPriority == p) {
                                vm.filterPriority = p
                            }
                        }
                    }.padding(.horizontal)
                }.padding(.vertical, 8)

                List {
                    ForEach(vm.filteredTasks) { task in
                        TaskRow(task: task) {
                            Task { await vm.toggleCompletion(task) }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddTaskView(vm: vm) }
            .task { await vm.loadTasks() }
        }
    }
}

struct AddTaskView: View {
    @ObservedObject var vm: TaskViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title    = ""
    @State private var subject  = ""
    @State private var dueDate  = Date()
    @State private var priority = TaskPriority.medium

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)
                    TextField("Subject", text: $subject)
                }
                Section("Schedule") {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard !title.isEmpty else { return }
                        Task {
                            await vm.addTask(
                                title: title, subject: subject,
                                dueDate: dueDate, priority: priority
                            )
                            dismiss()
                        }
                    }
                    .bold()
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

struct FilterChip: View {
    let label: String; let isSelected: Bool; let action: () -> Void
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
    let task: StudyTask; let onToggle: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .nestPurple : .gray).font(.title3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : .nestDark)
                Text(task.dueDate.fullDisplay).font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Text(task.priority.rawValue).font(.caption).bold()
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(task.isOverdue ? Color.red.opacity(0.15) : Color.nestLightPink)
                .foregroundColor(task.isOverdue ? .red : .nestPink)
                .cornerRadius(8)
        }.padding(.vertical, 4)
    }
}
