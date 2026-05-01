# SCREENS.md — Proovit Screen Specs

For each screen: **purpose**, **components**, **state owned**, **navigation**, **data model touchpoints**.

## Conventions

- **State owned** = what the screen itself owns (`@State`) vs. reads (`@Query`, `@Bindable`, environment).
- **Navigation** lists where you arrive from and where you go to.
- **Data model** lists which `@Model` types are read or written.

## Data model overview (informs every screen)

```
Tracker         id: UUID, name, colorHex, iconSymbolName, sortOrder, createdAt
ProgressEntry   id: UUID, trackerID: UUID, photoFilename, capturedAt
UserProfile     id: UUID, displayName, createdAt   (singleton row)
```

Photos themselves live on disk in `Application Support/Photos/<UUID>.jpg`. `ProgressEntry.photoFilename` is the lookup key.

---

## 0. First-Launch Onboarding

**Purpose:** Capture display name; seed default trackers (Fitness, Skincare, Hair Growth); defer permission prompts until each one is first needed.

**Components:** name `TextField`, "Continue" `Button`, brand mark.

**State owned:** `@State var displayName: String = ""`.

**Navigation:** Shown only when no `UserProfile` row exists. Replaces `RootTabView` until completed.

**Data model:** Writes one `UserProfile` row; writes three seed `Tracker` rows.

---

## 1. Home (Tab 1)

**Purpose:** Glance at all trackers, jump into one to log or review, capture quickly via the central FAB.

**Components:**
- Greeting + subhead ("Small steps compound. Capture today's version of yourself.")
- "TRACKERS" section: vertical list of `TrackerRow` (color dot, name, streak badge "47d", chevron); "+ Add new category" cell at the bottom
- "RECENT ENTRIES" section: horizontal `ScrollView` of recent thumbnails (last ~10 across all trackers)
- Bottom tab bar (custom: 5 slots, center is the camera FAB)

**State owned:** `@State var showingAddTracker: Bool`.

**Reads:** `@Query(sort: \.sortOrder) var trackers: [Tracker]`; `@Query(sort: \.capturedAt, order: .reverse) var recentEntries: [ProgressEntry]` (limit 10).

**Navigation:**
- Tracker row → `TrackerDetailView`
- "+ Add new category" → `EditTrackerSheet` (sheet)
- FAB → `CameraView` (full-screen cover); user picks a tracker if more than one exists
- Tab bar → other tabs

**Data model:** Reads `Tracker`, `ProgressEntry`. No writes.

---

## 2. Tracker Detail

**Purpose:** Show a single tracker's streak, monthly consistency, and the primary "Capture" CTA.

**Components:**
- Header (color dot + tracker name; back chevron to Home)
- Stat cards: Streak, This Month, Consistency %
- Month calendar grid: each day filled if logged, dim if missed; today highlighted
- Sticky "Capture <Tracker Name>" button at the bottom

**State owned:** `@State var visibleMonth: Date`; `@State var selectedDay: Date?` (drives `DayPhotosSheet`).

**Reads:** the `Tracker` (passed in or `@Bindable`); filtered `@Query` for that tracker's `ProgressEntry`s.

**Navigation:** From Home or Calendar. → `CameraView` with the tracker pre-selected. → `DayPhotosSheet` on day tap. Toolbar → `EditTrackerSheet`.

**Data model:** Reads `Tracker`, filtered `ProgressEntry`. Streak and consistency are computed by `StreakCalculator`, not stored.

---

## 3. Camera (full-screen modal)

**Purpose:** Capture a single timestamped photo. **Camera only — no gallery affordances.**

**Components:**
- `AVCaptureVideoPreviewLayer` wrapped in a `UIViewRepresentable`
- "LIVE" indicator (top-left)
- Tracker name (top center; tappable to switch trackers via inline picker)
- Close (X)
- Shutter button (large, centered)
- Flash toggle, camera-flip
- Footer text: "Camera only — no gallery uploads"

**State owned:** `@State var selectedTrackerID: UUID?`; `@State var isCapturing: Bool`. The `CameraSession` (`@Observable`) is created at view scope and torn down on dismiss.

**Navigation:** Full-screen cover from Home FAB or Tracker Detail. On capture → `CapturePreviewView`.

**Data model:** No writes here. Capture produces a `Data` blob held in memory until the preview screen confirms.

**Permissions:** First entry requests camera access. If denied, show in-screen message linking to Settings.

---

## 4. Capture Preview / Confirm

**Purpose:** Let the user discard or save the just-taken photo before it is persisted.

**Components:** Full-bleed image preview, tracker chip, "Retake" / "Save" buttons.

**State owned:** Image `Data` in memory; `@State var isSaving: Bool`.

**Navigation:** From Camera. "Retake" → back to Camera. "Save" → `PhotoStore.save(data:)` + create `ProgressEntry` → dismiss to whatever presented Camera.

**Data model:** Writes one `ProgressEntry`; writes one JPEG to disk via `PhotoStore.save(data:)`.

---

## 5. Calendar (Tab 2)

**Purpose:** Cross-tracker month view of consistency. Same calendar UX as Tracker Detail but with a top tracker filter.

**Components:** Tracker filter chips (All / Fitness / Skincare / Hair / …), month calendar, day-tap → `DayPhotosSheet`.

**State owned:** `@State var visibleMonth: Date`; `@State var trackerFilter: UUID?` (nil = All); `@State var selectedDay: Date?`.

**Reads:** `@Query` `ProgressEntry`s in the visible month, filtered by `trackerFilter` if set.

**Navigation:** Tab bar. Day-tap → `DayPhotosSheet`.

**Data model:** Reads `ProgressEntry`, `Tracker`.

---

## 6. Compare — Side by Side (Tab 4 default mode)

**Purpose:** Pick two dates within a tracker and view photos side by side with a summary.

**Components:** Mode segmented control ("Side by Side" / "Progress Reel"), tracker filter chips, two date-picker cards (labeled "Day 1" / "Day N"), summary block (Photos, Duration, Consistency).

**State owned:** `@State var selectedTrackerID: UUID`; `@State var leftDate: Date`; `@State var rightDate: Date`.

**Reads:** `ProgressEntry`s for the chosen tracker on the chosen dates.

**Navigation:** Tab bar. Mode toggle to Progress Reel.

**Data model:** Reads `Tracker`, `ProgressEntry`.

---

## 7. Compare — Progress Reel mode

**Purpose:** Auto-generate and play a timelapse from the tracker's photos; share via system share sheet.

**Components:** Mode segmented control, video player (`AVPlayerLayer` in a `UIViewRepresentable`), Day N / date overlay, scrubber labeled "Day 1 → Day N", "Share progress reel" button.

**State owned:** `@State var generationState: ReelState` (`.idle | .generating(progress: Double) | .ready(URL) | .failed(Error)`); `@State var selectedTrackerID: UUID`.

**Reads:** all `ProgressEntry`s for the selected tracker, date-sorted.

**Navigation:** Same tab as Side-by-Side; mode toggle.

**Services:** `VideoComposer.compose(entries:) async throws -> URL` writes an MP4 to a temporary directory using `AVAssetWriter`. Caller passes URL to `ShareLink`.

**Data model:** Reads `ProgressEntry`. Writes the composed video to a temp file (not tracked in SwiftData).

---

## 8. Profile (Tab 5)

**Purpose:** Identity + lifetime stats; surface preferences (reminder time, notifications, appearance); offer Privacy / Export Data / Help links.

**Components:**
- Avatar (initials), display name, "Member since <month year>"
- Stat cards: Total Photos, Best Streak, Trackers
- Preferences list: Reminder Time → time picker sheet; Appearance → System / Light / Dark; Notifications → toggle
- Account list: Privacy (static text), Export Data (zips photos + CSV → share sheet), Help & Support (mailto: link)

**State owned:** `@State var showingTimePicker: Bool`, `@State var showingEditProfile: Bool`, etc.

**Reads:** the singleton `UserProfile`; aggregate counts from `@Query`.

**Navigation:** Tab bar. Avatar tap → `EditProfileSheet` (display name change).

**Data model:** Reads/writes `UserProfile`. Reads `ProgressEntry`, `Tracker` for aggregates.

---

## 9. Edit Tracker Sheet (Add or Rename)

**Purpose:** Create a new tracker or edit an existing one — name, color, SF Symbol icon.

**Components:** name `TextField`, color swatches, icon grid (curated SF Symbols), "Save" / "Delete" / "Cancel".

**State owned:** Local copy of `Tracker` fields; `@State var isPresentingDeleteConfirm: Bool`.

**Navigation:** Sheet from Home (Add) or Tracker Detail toolbar (Edit).

**Data model:** Inserts or updates `Tracker`. Delete cascades: also deletes that tracker's `ProgressEntry`s and their photo files via `PhotoStore`.

---

## 10. Day Photos Sheet

**Purpose:** Show all photos captured on a specific date for the active tracker (or all trackers, if invoked from the Calendar tab with no filter).

**Components:** Date heading; photo grid; tap a photo → full-screen viewer.

**State owned:** `@State var selectedPhoto: ProgressEntry?`.

**Reads:** `ProgressEntry`s on that date (and tracker if filtered).

**Navigation:** Sheet from Tracker Detail or Calendar. → full-screen photo viewer.

---

## Recommended Build Order

This order gives early visible progress, defers the heaviest piece (video composition) to last, and keeps the app launching and usable after every step.

1. **Foundations** — three pieces, all in this step:
   - **Theme** — named colors in `Assets.xcassets` with Light + Dark variants (per `DESIGN.md`); `Theme` Swift enum in `Utilities/Theme.swift` exposing `Theme.accent`, `Theme.Spacing.lg`, `Theme.Radius.medium`, `Theme.trackerPalette`, `Theme.trackerSymbols`.
   - **Data model** — `Tracker`, `ProgressEntry`, `UserProfile` `@Model` classes; `PhotoStore` service for filesystem reads/writes.
   - **Pure logic** — `StreakCalculator` and `DateUtils` with Swift Testing unit tests.
2. **Onboarding + seed data** — first-launch name capture; seed three default trackers.
3. **Home (read-only)** — list trackers from SwiftData; placeholder thumbnails for "Recent entries".
4. **Custom tab bar with center FAB** — visual only at first; wire tab routing via `@State var selection`.
5. **Edit Tracker Sheet** — Home now lets you create custom trackers.
6. **Camera capture pipeline** — `CameraService`, preview layer, shutter, capture preview/confirm, save to disk + write `ProgressEntry`. *After this step, the app is end-to-end usable for one tracker.*
7. **Tracker Detail** — stats + month calendar + Day Photos Sheet.
8. **Calendar tab** — reuses calendar component from Tracker Detail with a tracker filter.
9. **Compare — Side by Side** — date pickers, summary computation.
10. **Profile + Preferences** — display name, lifetime stats, reminder time picker.
11. **Notifications service** — schedule daily local notification at user's reminder time; request permission on first toggle.
12. **Compare — Progress Reel** — `VideoComposer` (`AVAssetWriter`), video player, share sheet. Last because it's the heaviest build and benefits from real captured photos to test against.

Each step ends with the app still launching, building, and usable up to that point. No multi-step "big bang" merges.
