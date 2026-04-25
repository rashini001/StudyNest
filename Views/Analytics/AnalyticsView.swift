import SwiftUI
import Charts

struct AnalyticsView: View {
    @StateObject private var vm = AnalyticsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Summary Banner
                    summaryBanner

                    // Bar Chart: Weekly Study Hours
                    weeklyBarCard

                    // Donut Chart: Subject Breakdown
                    if !vm.subjectData.isEmpty {
                        subjectDonutCard
                    }

                    // Line Chart: 30 Day Streak Trend
                    streakLineCard

                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Visual Analytics")
            .navigationBarTitleDisplayMode(.large)
            .task { await vm.loadAnalytics() }
            .overlay {
                if vm.isLoading {
                    ProgressView()
                        .scaleEffect(1.4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.4))
                }
            }
        }
    }

    // Summary Banner

    private var summaryBanner: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [.nestPink, .nestPurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(20)
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 140)
                .offset(x: 260, y: -35)

            HStack(spacing: 0) {
                SummaryStatBlock(
                    value: formatHours(vm.totalWeeklyMinutes),
                    label: "This Week",
                    icon: "clock.fill"
                )
                statDivider
                SummaryStatBlock(
                    value: "\(vm.streakDays)d",
                    label: "Current Streak",
                    icon: "flame.fill"
                )
                statDivider
                SummaryStatBlock(
                    value: "\(vm.longestStreak)d",
                    label: "Best Streak",
                    icon: "trophy.fill"
                )
                statDivider
                SummaryStatBlock(
                    value: "\(vm.subjectData.count)",
                    label: "Subjects",
                    icon: "books.vertical.fill"
                )
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 8)
        }
        .frame(height: 100)
        .padding(.horizontal)
    }

    private var statDivider: some View {
        Divider()
            .background(Color.white.opacity(0.3))
            .frame(height: 44)
    }

    // Bar Chart Card

    private var weeklyBarCard: some View {
        AnalyticsCard(title: "Weekly Study Hours", icon: "chart.bar.fill") {
            if vm.weeklyData.isEmpty {
                emptyState("No sessions logged yet")
            } else {
                Chart(vm.weeklyData) { data in
                    BarMark(
                        x: .value("Day", data.day),
                        y: .value("Minutes", data.minutes)
                    )
                    .foregroundStyle(Color.nestPurple)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        if data.minutes > 0 {
                            Text(formatHours(data.minutes))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(Color.gray)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisValueLabel {
                            if let mins = value.as(Int.self) {
                                Text("\(mins)m")
                                    .font(.caption2)
                                    .foregroundStyle(Color.gray)
                            }
                        }
                    }
                }

                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("Includes session planner + Pomodoro time")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
            }
        }
    }

    // Donut Chart Card

    private var subjectDonutCard: some View {
        AnalyticsCard(title: "Subject Breakdown", icon: "chart.pie.fill") {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    Chart(vm.subjectData) { data in
                        SectorMark(
                            angle:         .value("Minutes", data.minutes),
                            innerRadius:   .ratio(0.58),
                            angularInset:  2
                        )
                        .foregroundStyle(data.color)
                        .cornerRadius(4)
                    }
                    .frame(width: 140, height: 140)
                    VStack(spacing: 2) {
                        Text(formatHours(vm.subjectData.reduce(0) { $0 + $1.minutes }))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.nestDark)
                        Text("total")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(vm.subjectData.prefix(6)) { d in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(d.color)
                                .frame(width: 10, height: 10)
                            Text(d.subject)
                                .font(.caption)
                                .foregroundColor(.nestDark)
                                .lineLimit(1)
                            Spacer()
                            Text(formatHours(d.minutes))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                        }
                    }
                    if vm.subjectData.count > 6 {
                        Text("+\(vm.subjectData.count - 6) more")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // Streak Line Chart Card

    private var streakLineCard: some View {
        AnalyticsCard(title: "30-Day Study Trend", icon: "waveform.path.ecg") {
            if vm.streakLineData.allSatisfy({ $0.minutes == 0 }) {
                emptyState("Start studying to see your trend")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        StreakChip(
                            icon:  "flame.fill",
                            color: .orange,
                            value: "\(vm.streakDays)d",
                            label: "Current"
                        )
                        StreakChip(
                            icon:  "trophy.fill",
                            color: .nestPurple,
                            value: "\(vm.longestStreak)d",
                            label: "Longest"
                        )
                        StreakChip(
                            icon:  "checkmark.circle.fill",
                            color: .green,
                            value: "\(vm.streakLineData.filter { $0.hasActivity }.count)",
                            label: "Active days"
                        )
                    }
                    Chart(vm.streakLineData) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(Color.nestPurple.opacity(0.15))
                        .interpolationMethod(.catmullRom)
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(Color.nestPurple)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                        if point.hasActivity {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Minutes", point.minutes)
                            )
                            .symbolSize(36)
                            .foregroundStyle(Color.nestPink)
                        }
                    }
                    .frame(height: 180)
                    .chartXAxis {
                        AxisMarks(values: stride(from: 0, through: 29, by: 7).compactMap {
                            Calendar.current.date(byAdding: .day, value: -$0, to: Date())
                        }) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .font(.caption2)
                                .foregroundStyle(Color.gray)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            AxisValueLabel {
                                if let mins = value.as(Int.self) {
                                    Text("\(mins)m")
                                        .font(.caption2)
                                        .foregroundStyle(Color.gray)
                                }
                            }
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            if let todayX = proxy.position(forX: Calendar.current.startOfDay(for: Date())) {
                                Rectangle()
                                    .fill(Color.nestPink.opacity(0.4))
                                    .frame(width: 1.5, height: geo.size.height)
                                    .position(x: todayX, y: geo.size.height / 2)
                            }
                        }
                    }
                }
            }
        }
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
    }
    private func formatHours(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0m" }
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

private struct AnalyticsCard<Content: View>: View {
    let title:   String
    let icon:    String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(.nestPurple)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.nestDark)
            }
            content()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: Color.nestPurple.opacity(0.08), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

// Summary Stat Block

struct SummaryStatBlock: View {
    let value: String
    let label: String
    let icon:  String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// Streak Chip

private struct StreakChip: View {
    let icon:  String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.nestDark)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.10))
        .cornerRadius(10)
    }
}


#Preview {
    AnalyticsView()
}
