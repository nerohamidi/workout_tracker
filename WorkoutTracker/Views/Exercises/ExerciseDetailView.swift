import SwiftUI
import SwiftData
import Charts

/// Detail view for an `ExerciseTemplate`. Shows the user's personal records — the
/// heaviest weight lifted at each rep count, derived from completed workout history —
/// and one progression chart per rep count with at least two data points.
///
/// PRs and progression data are computed on every view refresh, not stored. This
/// means they always reflect the current workout log: edit a past set and both the
/// records and the charts update automatically.
struct ExerciseDetailView: View {
    @Bindable var template: ExerciseTemplate
    @AppStorage("useMetric") private var useMetric = true

    private var records: [PersonalRecord] {
        PersonalRecord.records(for: template)
    }

    private var progression: [Int: [PersonalRecord.ProgressionPoint]] {
        PersonalRecord.progressionByReps(for: template)
    }

    /// Rep counts that have at least two data points and are therefore worth plotting.
    /// Single-point series collapse to a dot, which doesn't communicate progression.
    private var plottableRepCounts: [Int] {
        progression
            .filter { $0.value.count >= 2 }
            .keys
            .sorted()
    }

    var body: some View {
        List {
            Section("About") {
                LabeledContent("Category", value: template.category.rawValue)
                LabeledContent("Muscle Group", value: template.muscleGroup.rawValue)
                if template.isCustom {
                    LabeledContent("Source", value: "Custom")
                }
            }

            Section("Personal Records") {
                if template.category == .cardio {
                    Text("Personal records aren't tracked for cardio exercises.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if records.isEmpty {
                    Text("No records yet. Finish a workout with this exercise to see your maxes here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(records) { record in
                        HStack {
                            Text("\(record.reps) rep\(record.reps == 1 ? "" : "s")")
                                .fontWeight(.medium)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(formatted(record.weight)) \(useMetric ? "kg" : "lbs")")
                                    .fontWeight(.semibold)
                                Text(record.date, format: .dateTime.month().day().year())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if template.category == .strength && !plottableRepCounts.isEmpty {
                Section("Progression") {
                    ForEach(plottableRepCounts, id: \.self) { reps in
                        if let points = progression[reps] {
                            ProgressionChart(reps: reps, points: points, useMetric: useMetric)
                        }
                    }
                }
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

/// One line chart showing weight progression over time at a specific rep count.
/// Each data point is the heaviest set the user did at that rep count in a single
/// completed workout.
private struct ProgressionChart: View {
    let reps: Int
    let points: [PersonalRecord.ProgressionPoint]
    let useMetric: Bool

    private var unit: String { useMetric ? "kg" : "lbs" }

    private var deltaText: String? {
        guard let first = points.first, let last = points.last, first != last else { return nil }
        let delta = last.weight - first.weight
        let sign = delta >= 0 ? "+" : ""
        let formatted = delta.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", delta)
            : String(format: "%.1f", delta)
        return "\(sign)\(formatted) \(unit)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(reps) rep\(reps == 1 ? "" : "s")")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let deltaText {
                    Text(deltaText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(deltaText.hasPrefix("+") ? .green : .red)
                }
            }

            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.accentColor)
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(Color.accentColor)
            }
            .frame(height: 140)
            .chartYAxisLabel(unit, position: .leading)
        }
        .padding(.vertical, 4)
    }
}
