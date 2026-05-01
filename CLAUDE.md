# CLAUDE.md — Proovit Project Rules

**Read this every session before responding.** See `PRD.md` for product scope, `SCREENS.md` for screen specs and build order, and `DESIGN.md` for design tokens (colors, typography, spacing, radii).

## What this project is

Proovit is an iOS app for camera-only progress tracking across self-improvement domains (fitness, skincare, hair, custom). Built by a 4-person team for a university iOS development class.

**This is a learning project: idiomatic, explainable code beats clever abstractions.** The codebase is also a teaching artifact — future readers should be able to learn SwiftUI / SwiftData / AVFoundation from it.

## Hard Rules (never violate without asking)

1. **Never modify `Proovit.xcodeproj/`** — including `project.pbxproj`, schemes, or workspace settings. If a file needs to be added to the Xcode project, tell the human exactly where to drag it in.
2. **Never add gallery / `PHPicker` / `UIImagePickerController(.photoLibrary)` paths.** Camera-only is a product principle, not a configurable feature.
3. **Never add network calls, cloud SDKs, Firebase, CloudKit, or third-party analytics in v1.0.** Local-only persistence.
4. **Never use force-unwrap (`!`).** Use `guard let`, `if let`, or sensible defaults.
5. **Never delete or rename existing files without confirming first** — a teammate may have work-in-progress.
6. **Never add a Swift Package Manager dependency without asking.** Apple frameworks are fine to import.
7. **Never skip the explanation.** Non-trivial changes get a one-sentence reason and, where relevant, a `// 💡 Learn:` comment in code.
8. **Never hardcode design values.** Colors, font weights, spacing, and corner radii come from the `Theme` namespace (defined per `DESIGN.md`). No raw hex (`Color(red: …)`), no raw `Color("Accent")` outside `Theme.swift`, no raw `padding(16)` — use `Theme.Spacing.lg`. If a value isn't in `DESIGN.md`, stop and ask before introducing it.

## Tech Stack

- **Swift 5.9+**, **iOS 17.0** deployment target
- **SwiftUI** for all UI; **NavigationStack** (not `NavigationView`, not `NavigationSplitView`)
- **SwiftData** with `@Model` for persistence; never Core Data; never `UserDefaults` for app data (preferences only)
- **`@Observable`** macro for shared/derived state; **never `ObservableObject` / `@Published`** in new code
- **`async/await`** for all async work; never completion handlers, never Combine for new code
- **AVFoundation** for camera (`AVCaptureSession`) and video composition (`AVAssetWriter`)
- **UserNotifications** for the daily reminder

## Architecture Conventions

### Folder layout (under `Proovit/`)
```
Models/             SwiftData @Model classes (Tracker, ProgressEntry, UserProfile)
Views/              One file per screen, named <Screen>View.swift
Views/Components/   Small reusable views (StreakBadge, CategoryPill, CalendarGrid)
Services/           CameraService, VideoComposer, NotificationScheduler, PhotoStore
Utilities/          Pure helpers (StreakCalculator, DateUtils)
```

### State ownership

- **`@State`** — view-local ephemeral state (toggles, text fields, selection)
- **`@Query`** — SwiftData reads inside views
- **`@Environment(\.modelContext)`** — SwiftData writes
- **`@Observable` class** — shared state across multiple views (e.g. `CameraSession`)
- **`@Bindable`** — passing `@Observable` instances to child views with two-way binding

### Photos are NOT stored in SwiftData

SwiftData holds metadata only. Photos go to `FileManager.default.url(for: .applicationSupportDirectory, ...)/Photos/<UUID>.jpg`. The `ProgressEntry` model stores the filename only. One `PhotoStore` service owns all reads/writes — views never touch `FileManager` directly.

### View composition

- One screen = one top-level view file, < 200 lines preferred
- Pull subviews out aggressively; conditional UI in `body` is a smell
- `#Preview` for every view, with sample data

## Coding Style

- 4-space indent; Swift's default brace style
- Trailing closures only when the closure is the last and primary argument
- Default to `let x = ...` without an explicit type; annotate when it aids reading
- Don't write multi-paragraph doc comments. One short `///` line on non-obvious public API.
- **Do** leave **`// 💡 Learn:`** comments on non-trivial SwiftUI / SwiftData / AVFoundation idioms — this codebase teaches.
- Don't write `// adds two numbers` above `a + b`. Comments earn their place.

## Testing

- v1.0 does **not** require UI tests
- v1.0 **does** require unit tests for: streak math, date utilities, video-composer helpers
- Use **Swift Testing** (`import Testing`, `@Test`), not XCTest, for new tests

## How I work as your assistant

- **WHY before HOW.** State the trade-off in one sentence, then show the change.
- **Small diffs.** Don't refactor adjacent code unless the task requires it.
- **List files before editing** when a change spans more than 2 files; let the team confirm.
- **Stop and ask** before:
  - Adding a Swift Package Manager dependency
  - Deleting or renaming files
  - Changing the data model in a way that requires a migration
  - Anything affecting the Xcode project file
- **Pair code with brief teaching comments** on idioms a SwiftUI newcomer wouldn't know.
- **No clever abstractions.** Three similar lines beat a premature protocol.
- **Verify before claiming done.** If I can't run the app to check a UI change, I'll say so explicitly.
- **One concept per message.** If a change touches three new ideas, surface only the most important one in prose; touch the others with `// 💡 Learn:` comments.
