# DESIGN.md — Proovit Design Tokens

**Source of truth for colors, typography, spacing, and radii.** Views never hardcode these values — reference them through the `Theme` namespace (or named `Color` assets in `Assets.xcassets`).

## Aesthetic

Minimal, restrained, warm. Off-white background, deep forest-green accent, near-black text. No gradients, no glassmorphism, no ornament. Photos and progress data are the visual focus; chrome stays out of the way.

The brand is light-first. Dark-mode support ships with v1.0 by mirroring every named color in the Asset Catalog (each entry has a Light and a Dark appearance).

## Color Palette

> **Note on hex values:** the values below are approximate, eyeballed from the deck mockups. The design owner should confirm exact hex values and update this file before they get baked into the Asset Catalog. The *names* and *semantic roles* are stable; only the precise values are tentative.

### Brand

| Token | Light value (approx.) | Use |
|---|---|---|
| `Theme.background` | warm cream `#F5F3EC` | App and screen backgrounds |
| `Theme.surface` | white `#FFFFFF` | Cards, sheets, list rows lifted off the background |
| `Theme.accent` | deep forest green `#2E5340` | Primary CTAs, FAB, today highlight, "Logged" indicator |
| `Theme.accentMuted` | accent at 12% opacity | Calendar logged-day fill, selection backgrounds |

### Text

| Token | Approx. | Use |
|---|---|---|
| `Theme.textPrimary` | near-black `#181A18` | Headings, primary copy |
| `Theme.textSecondary` | gray `#6F7068` | Subtitles, captions, supporting copy |
| `Theme.textTertiary` | light gray `#A4A6A0` | Placeholder, disabled, missed-day text |

### Tracker palette (curated picker shown in Edit Tracker sheet)

Users pick one of these when creating a tracker. **Do not allow a free-form color picker** — the curated set keeps the Home screen visually coherent.

| Name | Approx. hex | Default for |
|---|---|---|
| Forest | `#2E5340` | Fitness *(same as `Theme.accent`)* |
| Lilac | `#7B5FB8` | Skincare |
| Amber | `#D4A55A` | Hair Growth |
| Coral | `#D9755A` | — |
| Slate | `#5B6B7A` | — |
| Plum | `#8E4F6E` | — |

### Semantic

| Token | Maps to |
|---|---|
| `Theme.success` | `Theme.accent` (we don't introduce a second green) |
| `Theme.warning` | Amber `#D4A55A` |
| `Theme.danger` | `#C75A4F` (used for destructive actions only — Delete Tracker) |
| `Theme.divider` | `#E5E3DB` (background darkened ~6%) |

## Typography

Use SwiftUI's semantic text styles, not raw point sizes. They scale with Dynamic Type for free.

| Where | SwiftUI style | Weight |
|---|---|---|
| Screen titles ("Home", "Compare") | `.largeTitle` | `.bold` |
| Section labels ("TRACKERS", "RECENT ENTRIES") | `.caption` | `.medium`, uppercased, tracking +1 |
| Card numbers ("47d", "88%", "142") | `.title` | `.bold` |
| Card labels ("Streak", "Consistency") | `.caption` | `.regular` |
| Body copy | `.body` | `.regular` |
| Tab bar labels | `.caption2` | `.regular` |

Default font is SF Pro (the system font). **Do not import a custom font in v1.0.**

## Spacing scale

Use multiples of 4. Lives in `Theme.Spacing`:

| Token | Value | Typical use |
|---|---|---|
| `xxs` | 2 | Hairline gaps |
| `xs` | 4 | Inside compact pills |
| `sm` | 8 | Between adjacent labels |
| `md` | 12 | Card internal padding |
| `lg` | 16 | Default screen horizontal padding |
| `xl` | 24 | Section separation |
| `xxl` | 32 | Above primary CTAs |

## Corner radii

Lives in `Theme.Radius`:

| Token | Value | Typical use |
|---|---|---|
| `small` | 8 | Pills, chips, filter tabs |
| `medium` | 14 | Cards, list rows, sheets |
| `large` | 22 | Camera shutter ring, prominent CTAs |
| `full` | `.infinity` | Avatars, FAB, circular buttons |

## Shadows

Almost nothing — the aesthetic is flat. The only allowed elevations:

- **Sheet** — system default
- **Camera FAB** — subtle: y=4, blur=12, opacity 0.12

No drop-shadows on cards, list rows, or buttons.

## Iconography

- **System icons:** SF Symbols only. Default `.regular` weight; `.semibold` for tab-bar selected state.
- **Tracker icons:** users pick from a curated SF Symbol set in the Edit Tracker sheet. Curated list lives in code as `Theme.trackerSymbols: [String]`.
- **App-wide spacing/sizing for icons:** 20pt for inline, 24pt for tab bar, 28pt for camera controls, 32pt for FAB glyph.

## Implementation pattern

When we reach Step 1 of the build order:

1. **Asset Catalog** — add named colors to `Assets.xcassets`, each with Light and Dark appearances. Names match this doc (`Background`, `Surface`, `Accent`, `TextPrimary`, …).
2. **`Theme` Swift enum** — single source of truth in `Utilities/Theme.swift`. Exposes:
   - `static let background = Color("Background")` etc. for every brand and text token
   - Nested `Theme.Spacing` enum with `static let lg: CGFloat = 16` etc.
   - Nested `Theme.Radius` enum with `static let medium: CGFloat = 14` etc.
   - `Theme.trackerPalette: [TrackerColor]` — the curated picker list
   - `Theme.trackerSymbols: [String]` — the curated SF Symbol list
3. **Views reference `Theme.*` only.** Never `Color(red: 0.18, …)`. Never `Color("Accent")` outside `Theme.swift`. Never raw `12` for spacing/radius.
4. The `EditTrackerSheet` reads `Theme.trackerPalette` and `Theme.trackerSymbols` to render the pickers.

A concrete `Theme.swift` lands in Step 1 of `SCREENS.md`'s build order — not before.
