import Foundation
import SwiftData

/// A named ordered rotation of routines (e.g. "PPL" → Push, Pull, Legs).
///
/// A split tracks `currentIndex`, the position of the routine that should run next.
/// When a workout started from the split is finished, `currentIndex` advances by one
/// (wrapping back to 0 at the end). This makes "what's today?" answerable from the
/// detail view without the user having to remember.
@Model
final class TrainingSplit {
    /// User-visible name (e.g. "PPL", "Upper/Lower").
    var name: String

    /// When the split was created — used for stable sorting in lists.
    var dateCreated: Date

    /// Index of the next routine to run, into `sortedRoutines`. Wraps modulo count
    /// when advanced past the end. Stays in [0, count) as long as the split is non-empty;
    /// callers must guard against an empty split before indexing.
    var currentIndex: Int

    /// Routines in this split, ordered by `SplitRoutine.order`. Cascade-deleted with
    /// the split (the underlying `Routine` records are NOT deleted — splits only
    /// reference them).
    @Relationship(deleteRule: .cascade)
    var routines: [SplitRoutine] = []

    /// Routines in display order.
    var sortedRoutines: [SplitRoutine] {
        routines.sorted { $0.order < $1.order }
    }

    /// The routine that should run next, or `nil` if the split is empty or its current
    /// index points at an entry whose underlying `Routine` was deleted.
    var nextRoutine: Routine? {
        let sorted = sortedRoutines
        guard !sorted.isEmpty else { return nil }
        let safeIndex = min(max(currentIndex, 0), sorted.count - 1)
        return sorted[safeIndex].routine
    }

    init(name: String, dateCreated: Date = .now, currentIndex: Int = 0) {
        self.name = name
        self.dateCreated = dateCreated
        self.currentIndex = currentIndex
    }

    /// Advance the rotation by one, wrapping at the end. No-op for an empty split.
    func advance() {
        let count = routines.count
        guard count > 0 else { return }
        currentIndex = (currentIndex + 1) % count
    }
}
