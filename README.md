# Workout Tracker

A simple, no-frills iOS app for logging workouts. Supports both strength training (sets/reps/weight) and cardio (duration/distance).

## Features

- Start and log workouts with a built-in timer
- 30+ pre-loaded exercises across chest, back, legs, shoulders, arms, core, and cardio
- Add custom exercises (from the Exercises tab or inline during a workout)
- Multi-select when adding exercises to a workout
- Track strength sets (reps + weight) and cardio entries (duration + distance)
- View workout history with full details
- Toggle between metric (kg/km) and imperial (lbs/mi) units
- Dark mode by default, with Light / System / Dark toggle in Settings

## Tech Stack

- SwiftUI
- SwiftData (persistence)
- iOS 17+ (uses iOS 18+ `Tab` API where available, with `.tabItem` fallback)
- No third-party dependencies

## Getting Started

1. Open `WorkoutTracker.xcodeproj` in Xcode 15+
2. Select an iPhone simulator
3. Build and run (Cmd+R)

### StoreKit (In-App Purchases) Setup

The app uses StoreKit 2 for Plus and Pro subscriptions. To test purchases locally in the simulator:

1. Open the project in Xcode
2. **File > New > File > StoreKit Configuration File** — name it anything (e.g. `storekit_config`)
3. In the StoreKit config editor, click **+** and select **Add Auto-Renewable Subscription**
4. Create a subscription group (e.g. "Plans") and add two subscriptions:
   - **Plus**: Product ID `com.workouttracker.plus`, Price `$3.00`, Duration 1 Month
   - **Pro**: Product ID `com.workouttracker.pro`, Price `$5.00`, Duration 1 Month
5. **Product > Scheme > Edit Scheme** (Cmd+<) > **Run** > **Options** tab
6. Set **StoreKit Configuration** to the file you just created
7. Build and run — purchases will now work in the simulator without a real App Store Connect setup

## Architecture

The app is a thin SwiftUI layer over a SwiftData model graph. There is no view-model layer — views read directly from `@Query` and write through `@Bindable` model instances.

```
WorkoutTracker/
├── WorkoutTrackerApp.swift   App entry point + ModelContainer setup + library seed
├── ContentView.swift         Tab bar + AppearanceMode enum
├── Models/                   SwiftData @Model classes (the data graph)
├── Views/
│   ├── Workout/              Start, log, finish a workout
│   ├── History/              Past workouts list + detail
│   ├── Exercises/            Library browser + custom exercise creation
│   └── Settings/             Units, appearance, about
└── Data/
    └── ExerciseLibrary.swift Seed data for the pre-built exercise library
```

### Data Model

```
ExerciseTemplate ─┐
  name              ├──< WorkoutExercise >── Workout
  category          │     order                date
  muscleGroup       │     │                    notes
  isCustom          │     │                    durationSeconds
                    │     │                    isCompleted
                    │     ├──< ExerciseSet     │
                    │     │     setNumber      │
                    │     │     reps           │
                    │     │     weight         │
                    │     │                    │
                    │     └──< CardioEntry     │
                    │           durationMinutes│
                    │           distance       │
```

- **ExerciseTemplate** — A reusable exercise definition. Either pre-seeded (`isCustom == false`) or user-created (`isCustom == true`). Templates persist across workouts.
- **Workout** — A single training session. Owns its `WorkoutExercise` entries via cascade delete.
- **WorkoutExercise** — Links a template to a workout, with an `order` for display sequencing. Owns its sets and cardio entries via cascade delete.
- **ExerciseSet** — A single strength set: `setNumber`, `reps`, `weight`.
- **CardioEntry** — A single cardio session: `durationMinutes`, `distance`.

Strength exercises use `sets`; cardio exercises use `cardioEntries`. The `WorkoutExercise.isCardio` computed property gates which logging UI is shown.

### Persistence Notes

- The `ModelContainer` is built in `WorkoutTrackerApp.init()` (not as a stored-property closure) so seeding completes before any `@Query` runs.
- If a schema mismatch is detected (e.g. after a model change), the app deletes the old store and retries — see the catch block in `WorkoutTrackerApp.init`.
- `ExerciseLibrary.seedIfNeeded` is idempotent: it only seeds when the store contains zero `ExerciseTemplate` records.

## Running Tests

The test target uses an in-memory `ModelContainer` so each test runs in isolation with no on-disk side effects.

```bash
xcodebuild test \
  -project WorkoutTracker.xcodeproj \
  -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -parallel-testing-enabled NO
```

`-parallel-testing-enabled NO` is required: SwiftData's global `PersistentIdentifier` registry is shared across in-process test clones, so parallel runs cause "Duplicate registration attempt" crashes.

The suite covers:

- `Workout.formattedDuration` formatting across all hour/minute combinations
- `Workout` and `ExerciseTemplate` init defaults
- `sortedExercises` and `sortedSets` ordering
- `WorkoutExercise.isCardio` for cardio, strength, and nil templates
- `ExerciseLibrary` seeding (insertion, idempotency, skipping when non-empty, custom-flag preservation, no duplicates)
- Cascade-style deletion (workout → exercises → sets, exercise → cardio entries)
- A full end-to-end workflow: seed, start workout, add strength + cardio, finish, read back
- `AppearanceMode` color-scheme mapping and raw-value roundtrip

### Test Pattern Caveat

When constructing `@Model` objects in tests, **do not** pass an already-inserted relationship target to the init. Setting `WorkoutExercise(exerciseTemplate: template)` triggers SwiftData to auto-register the new exercise via the template's inverse relationship. A subsequent `context.insert(exercise)` then crashes with "Duplicate registration attempt".

The tests use this safer pattern instead:

```swift
let exercise = WorkoutExercise(order: 0)
workout.exercises.append(exercise)   // wires up via parent's collection
exercise.exerciseTemplate = template  // assign the template afterward
```

## License

MIT
