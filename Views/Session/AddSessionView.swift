import SwiftUI

struct AddSessionView: View {

    @ObservedObject var vm: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Form State
    @State private var subject = ""
    @State private var startTime = Date().roundedToNextHour()
    @State private var endTime = Date().roundedToNextHour().addingTimeInterval(3600)
    @State private var notes = ""
    @State private var showTimePicker = false
    @FocusState private var subjectFocused: Bool

    // Suggested subjects for quick pick
    private let suggestions = ["Mathematics", "Physics", "Chemistry", "Biology",
                                "History", "Literature", "Computer Science", "Economics"]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {

                    // MARK: Header Banner
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [.nestPurple, .nestPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Circle()
                            .fill(Color.white.opacity(0.07))
                            .frame(width: 100)
                            .offset(x: 280, y: -10)

                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: "timer")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.85))
                            Text("New Study Session")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Syncs to Apple Calendar automatically")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.75))
                        }
                        .padding(18)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .cornerRadius(20)
                    .padding(.horizontal)

                    // MARK: Subject Field
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Subject", systemImage: "book.closed.fill")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.nestDark)

                        TextField("e.g. Mathematics", text: $subject)
                            .focused($subjectFocused)
                            .padding(14)
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(subjectFocused ? Color.nestPurple : Color.gray.opacity(0.2), lineWidth: 1.5)
                            )
                            .shadow(color: Color.nestPurple.opacity(0.06), radius: 6, x: 0, y: 3)

                        // Quick-pick chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions, id: \.self) { s in
                                    Button {
                                        subject = s
                                        subjectFocused = false
                                    } label: {
                                        Text(s)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(subject == s
                                                ? LinearGradient(colors: [.nestPink, .nestPurple],
                                                                  startPoint: .leading, endPoint: .trailing)
                                                : LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)],
                                                                  startPoint: .leading, endPoint: .trailing)
                                            )
                                            .foregroundColor(subject == s ? .white : .nestDark)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // MARK: Time Pickers
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Schedule", systemImage: "calendar.badge.clock")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.nestDark)

                        // Start time
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(startTime.sessionTimeDisplay)
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundColor(.nestPurple)
                            }
                            Spacer()
                            DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .onChange(of: startTime) { _, new in
                                    if endTime <= new {
                                        endTime = new.addingTimeInterval(3600)
                                    }
                                }
                        }
                        .padding(14)
                        .background(Color(.systemBackground))
                        .cornerRadius(14)
                        .shadow(color: Color.nestPurple.opacity(0.06), radius: 6, x: 0, y: 3)

                        // End time
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("End")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(endTime.sessionTimeDisplay)
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundColor(.nestPink)
                            }
                            Spacer()
                            DatePicker("", selection: $endTime,
                                       in: startTime.addingTimeInterval(300)...,
                                       displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                        .padding(14)
                        .background(Color(.systemBackground))
                        .cornerRadius(14)
                        .shadow(color: Color.nestPink.opacity(0.06), radius: 6, x: 0, y: 3)

                        // Duration badge
                        let mins = max(0, Int(endTime.timeIntervalSince(startTime) / 60))
                        HStack(spacing: 6) {
                            Image(systemName: "clock.badge.checkmark")
                                .font(.caption)
                            Text("Duration: \(formatDuration(mins))")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.nestPurple)
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal)

                    // MARK: Notes Field
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Notes (optional)", systemImage: "text.alignleft")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.nestDark)

                        TextEditor(text: $notes)
                            .frame(minHeight: 90)
                            .padding(10)
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                    }
                    .padding(.horizontal)

                    // MARK: Calendar Info Banner
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(
                                LinearGradient(colors: [.nestPink, .nestPurple],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto Calendar Alerts")
                                .font(.caption).fontWeight(.semibold).foregroundColor(.nestDark)
                            Text("24-hour & 1-hour reminders will be added")
                                .font(.caption2).foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.nestPurple.opacity(0.07))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.nestPurple.opacity(0.15), lineWidth: 1))
                    .padding(.horizontal)

                    // MARK: Error
                    if let err = vm.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                            Text(err).font(.caption).foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }

                    // MARK: Save Button
                    Button {
                        Task {
                            await vm.addSession(
                                subject: subject,
                                startTime: startTime,
                                endTime: endTime,
                                notes: notes
                            )
                            if vm.errorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "calendar.badge.plus")
                                Text("Save & Add to Calendar")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            subject.trimmingCharacters(in: .whitespaces).isEmpty
                            ? AnyView(Color.gray.opacity(0.3))
                            : AnyView(LinearGradient(colors: [.nestPink, .nestPurple],
                                                      startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(vm.isLoading || subject.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.nestPurple)
                }
            }
            .onTapGesture { subjectFocused = false }
        }
    }

    // MARK: - Helpers
    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60; let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}

// MARK: - Date helpers (local to this file)
private extension Date {
    func roundedToNextHour() -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour], from: self)
        comps.hour = (comps.hour ?? 0) + 1
        comps.minute = 0
        return cal.date(from: comps) ?? self
    }

    var sessionTimeDisplay: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: self)
    }
}
