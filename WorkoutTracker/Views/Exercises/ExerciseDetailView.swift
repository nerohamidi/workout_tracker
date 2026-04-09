import SwiftUI
import SwiftData

/// Detail view for an `ExerciseTemplate`. Shows the user's personal records — the
/// heaviest weight lifted at each rep count, derived from completed workout history.
///
/// PRs are computed on appear (and on every view refresh) by `PersonalRecord.records(for:)`,
/// not stored. This means they always reflect the current workout log: edit a past set
/// and the records update automatically.
struct ExerciseDetailView: View {
    @Bindable var template: ExerciseTemplate
    @AppStorage("useMetric") private var useMetric = true

    private var records: [PersonalRecord] {
        PersonalRecord.records(for: template)
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
