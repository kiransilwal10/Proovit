# Proovit — Product Requirements (v1.0)

**Tagline:** Your Progress, Proven.

## Problem

People quit self-improvement routines because:
- No visibility into actual progress (the change is too gradual to feel)
- Inconsistent or absent photographic records
- Friction from juggling separate apps for different domains (fitness, skincare, hair, etc.)

## Users

Anyone tracking gradual change at any scale: the university student building a workout habit, the teen new to the gym, the skincare creator documenting routine outcomes, the middle-aged user tracking hair-growth treatment.

What they share: they need **visible, authentic evidence** of progress and a **frictionless** capture loop.

## MVP Feature List (v1.0)

1. **Camera-only photo capture** — opens camera directly; no gallery import; each photo is timestamped and tagged to a tracker.
2. **Multi-tracker support** — seeded with Fitness, Skincare, Hair Growth on first launch; user can create custom trackers (name, color, SF Symbol icon).
3. **Daily streak per tracker** — strict rule: missing any calendar day resets that tracker's streak to 0.
4. **Calendar view** — month-at-a-glance per tracker; logged days highlighted; tap a day to see that day's photos.
5. **Side-by-side comparison** — pick any two dates within a tracker; view photos next to each other with a summary (count, duration, consistency %).
6. **Progress Reel** — auto-generated timelapse video composed from a tracker's photos, with date overlays on each frame; shareable via system share sheet.
7. **Daily local notification** — user picks a single reminder time; notification fires once per day.
8. **Local profile** — display name + auto-generated initials avatar; lifetime stats (total photos, best streak, tracker count). No sign-in, no auth, no backend.
9. **First-launch onboarding** — single-step name prompt; seed default trackers; request camera + notification permissions on first need.

## Tech Stack

| Layer | Choice |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI, NavigationStack |
| Persistence | SwiftData (`@Model`) |
| Photo storage | File system (`Application Support/Photos/`), filename referenced by `@Model` |
| Camera | AVFoundation (`AVCaptureSession`) |
| Video composition | AVFoundation (`AVAssetWriter`) |
| Notifications | UserNotifications |
| Concurrency | `async/await`; `@Observable` for shared state |
| Min target | iOS 17.0 |

## Out of Scope (v1.0)

- Gallery / `PHPicker` imports — camera-only is a product principle, not a configurable feature
- Cloud sync, accounts, sign-in (deferred to v1.1+ as a stretch goal)
- "Align with previous pose" ghost overlay on the camera (deferred to v1.1)
- Multi-device sync, web companion, social feed
- AI-generated insights, automatic before/after detection
- Per-tracker reminder schedules (one app-wide reminder time in v1.0)
- Photo editing (cropping, filters)
- iPad-specific layouts (universal but iPhone-first)

## Success Criteria

This is a learning project, so success means **shippable + idiomatic**, not market metrics.

**Functional**
- All 9 MVP features implemented and stable on iPhone (iOS 17+)
- No crashes during the 2-week closed beta at the University of Southern Mississippi
- Beta users can complete the full journey: create tracker → capture 3+ photos across 3+ days → view side-by-side comparison → generate and share a Progress Reel
- App passes archive build with no warnings

**Code quality**
- Codebase reads idiomatically to a SwiftUI reviewer (no force unwraps, no completion-handler-style code in new files, no manual change-publishing)
- Each major subsystem (camera, video, notifications, streak math) has unit-test coverage of its pure logic

**Learning**
- Each team member can explain how SwiftData, NavigationStack, AVCaptureSession, and AVAssetWriter work in this codebase

## Team

Kiran Silwal · Rupak Raut · Nishit Thapa · Maddox Elarton
