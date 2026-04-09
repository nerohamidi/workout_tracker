import Foundation
import SwiftData

/// Join entity that puts a `Routine` into a `TrainingSplit` at a specific position.
///
/// SwiftData many-to-many relationships don't preserve order, so we need an explicit
/// join model with an `order` field. The split owns these entries (cascade); deleting
/// a referenced `Routine` nullifies the entry's back-reference instead of deleting it.
@Model
final class SplitRoutine {
    /// Position in the split's rotation (0-based).
    var order: Int

    /// The routine this entry points at. Nullable so deleting a routine elsewhere
    /// doesn't take the split down with it.
    var routine: Routine?

    /// The split that owns this entry. Set automatically when appended to
    /// `TrainingSplit.routines`.
    var split: TrainingSplit?

    init(order: Int, routine: Routine? = nil, split: TrainingSplit? = nil) {
        self.order = order
        self.routine = routine
        self.split = split
    }
}
