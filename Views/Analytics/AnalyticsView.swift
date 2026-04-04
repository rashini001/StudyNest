import SwiftUI
import Charts

struct AnalyticsView: View {
    @StateObject private var vm = AnalyticsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: - Top Summary Banner
                    ZStack(alignment: .leading) {
                        LinearGradient(
                            colors: [.nestPink, .nestPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Circle()
                            .fill(Color.white.opacity(0.07))
                            .frame(width: 120)
                            .offset(x: 280, y: -30)

                        HStack(spacing: 0) {
                            SummaryStatBlock(
                                value: "\(vm.totalWeeklyMinutes / 60)h",
                                label: "24h Total",
                                icon: "clock.fill"
                            )
                            Divider().background(Color.white.opacity(0.3)).frame(height: 44)
                            SummaryStatBlock(
                                value: "\(vm.streakDays)d",
                                label: "7 Day Streak",
                                icon: "flame.fill"
                            )
                            Divider().background(Color.white.opacity(0.3)).frame(height: 44)
                            SummaryStatBlock(
                                value: "\(vm.subjectData.count)",
                                label: "Subjects",
                                icon: "books.vertical.fill"
                            )
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 8)
                    }
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .frame(height: 100)

                    // MARK: - Monthly Study Hours (Bar Chart)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Monthly Study Hours")
                            .font(.headline)
                            .foregroundColor(.nestDark)

                        if vm.weeklyData.isEmpty {
                            Text("No data yet")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                        } else {
                            Chart(vm.weeklyData) { data in
                                BarMark(
                                    x: .value("Day", data.day),
                                    y: .value("Min", data.minutes)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.nestPink, .nestPurple],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .cornerRadius(6)
                            }
                            .frame(height: 160)
                            .chartXAxis {
                                AxisMarks(values: .automatic) { _ in
                                    AxisValueLabel()
                                        .font(.caption2)
                                        .foregroundStyle(Color.gray)
                                }
                            }
                            .chartYAxis {
                                AxisMarks(values: .automatic) { _ in
                                    AxisValueLabel()
                                        .font(.caption2)
                                        .foregroundStyle(Color.gray)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(18)
                    .shadow(color: Color.nestPurple.opacity(0.08), radius: 8, x: 0, y: 4)
                    .padding(.horizontal)

                    // MARK: - Subject Breakdown (Donut)
                    if !vm.subjectData.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Subject Breakdown")
                                .font(.headline)
                                .foregroundColor(.nestDark)

                            HStack(alignment: .top, spacing: 16) {
                                Chart(vm.subjectData) { data in
                                    SectorMark(
                                        angle: .value("Min", data.minutes),
                                        innerRadius: .ratio(0.55),
                                        angularInset: 2
                                    )
                                    .foregroundStyle(data.color)
                                    .cornerRadius(4)
                                }
                                .frame(width: 130, height: 130)

                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(vm.subjectData.prefix(5)) { d in
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(d.color)
                                                .frame(width: 10, height: 10)
                                            Text(d.subject)
                                                .font(.caption)
                                                .foregroundColor(.nestDark)
                                                .lineLimit(1)
                                            Spacer()
                                            Text("\(d.minutes)m")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(18)
                        .shadow(color: Color.nestPurple.opacity(0.08), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                    }

                    // MARK: - Streak Calendar (7 days)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("7 Day Streak")
                            .font(.headline)
                            .foregroundColor(.nestDark)

                        HStack(spacing: 8) {
                            ForEach(0..<7, id: \.self) { i in
                                let date = Calendar.current.date(byAdding: .day, value: -(6 - i), to: Date()) ?? Date()
                                let dayLabel = date.formatted(.dateTime.weekday(.abbreviated))
                                let isActive = i < vm.streakDays

                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(isActive
                                                  ? AnyShapeStyle(LinearGradient(colors: [.nestPink, .nestPurple],
                                                                                  startPoint: .top, endPoint: .bottom))
                                                  : AnyShapeStyle(Color.nestLightPurple))
                                            .frame(width: 36, height: 36)
                                        if isActive {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    Text(dayLabel.prefix(1))
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(18)
                    .shadow(color: Color.nestPurple.opacity(0.08), radius: 8, x: 0, y: 4)
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Visual Analytics")
            .navigationBarTitleDisplayMode(.large)
            .task { await vm.loadAnalytics() }
        }
    }
}

struct SummaryStatBlock: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }
}
