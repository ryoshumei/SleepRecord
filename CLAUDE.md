# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

All `xcodebuild` invocations must be prefixed with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` because `xcode-select` on this machine points to `/Library/Developer/CommandLineTools` (CLI tools only). Without this, `xcrun simctl` and the simulator plugins won't be found.

**Regenerate Xcode project from YAML (required after adding/removing source files):**
```bash
xcodegen generate
```

**Build:**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

**Run all tests (current pass: 34/34 in ~0.05s):**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test
```

**Run a single test class:**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test \
  -only-testing:SleepRecordTests/ChartCellCalculatorTests
```

**Quick syntax / type check without xcodebuild:**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --sdk iphonesimulator \
  swiftc -typecheck -target arm64-apple-ios26.4-simulator \
  SleepRecord/Models/*.swift SleepRecord/Services/*.swift SleepRecord/Utilities/*.swift \
  SleepRecord/Views/Home/*.swift SleepRecord/Views/Chart/*.swift \
  SleepRecord/Views/Settings/*.swift SleepRecord/Views/PDF/*.swift \
  SleepRecord/SleepRecordApp.swift
```
Useful when iterating on a single file — much faster than xcodebuild.

**Available simulators on this machine:** iPhone 17, iPhone 17 Pro, iPhone 17 Pro Max, iPhone 17e, iPhone Air, iPad (A16), iPad Air/Pro 11 & 13. There is **no iPhone 16** simulator.

## Architecture

**Stack:** SwiftUI + SwiftData + CloudKit + PDFKit + UserNotifications. iOS 26.4+, Swift 5.9+. No third-party dependencies. All UI strings are in Japanese.

**Three-layer + state machine:**

- **Models/** — `SleepSession` is the only SwiftData `@Model`. Holds four timestamps (`bedInAt` non-optional, `bedOutAt` / `asleepAt` / `awakeAt` optional). An in-progress session has `bedOutAt == nil`. **All non-optional fields must have property-level defaults** (CloudKit constraint, see below).

- **Services/** — Pure logic, no SwiftUI dependencies:
  - `DataStore` — singleton `ModelContainer`. Checks `FileManager.ubiquityIdentityToken` first; only attempts CloudKit when iCloud is signed in (otherwise CloudKit framework hard-traps with `brk #1` from `NSCloudKitMirroringDelegate`). Falls back through CloudKit → local-on-disk → in-memory. The local fallback uses a separately-named configuration ("Local") so it never collides with a partially-initialized "Cloud" store. Test/debug helper: `DataStore.inMemory()`.
  - `SleepStateMachine` — enum with four states (`.empty`, `.inBed`, `.correctionPending`, `.completed`) computed from the active session.
  - `ChartCellCalculator` — projects `[SleepSession]` onto a 24-cell grid per calendar day using "any-overlap = mark cell" rule. Defensively skips sessions where `bedInAt >= bedEnd` or `asleepAt >= awakeAt` (Swift's `Range` traps if `lower > upper`).
  - `BackfillDetector` — when "おはよう" is tapped without an active session, suggests previous-day 23:00 as default `bedInAt`.
  - `SleepRecordValidator` — pure function that enforces `bedInAt < bedOutAt` and `bedInAt ≤ asleepAt ≤ awakeAt ≤ bedOutAt`. Returns `Issue?` and a Japanese localized message. Used by both `DayEditSheet` and `MorningCorrectionSheet` to disable Save and show inline error.
  - `NotificationScheduler` — `UNUserNotificationCenter` wrapper for the daily bedtime reminder.
  - `PDFExporter` — A4 portrait PDF via PDFKit, 35 days per page, multi-page when range is longer. `pages(totalDays:)` is `nonisolated` so unit tests don't need `@MainActor`.

- **Views/** — Two tabs: `Home` (2-tap UX: night 🌙 → morning ☀️ → correction sheet auto-presents) and `Chart` (monthly grid + day edit + PDF export). `Settings` is reachable via a gear icon from Home (sheet, not a tab).

**Data flow:** User tap → modify `SleepSession` in `ModelContext` → SwiftData persists → `@Query` refreshes views → `SleepStateMachine` recomputes button state → `ChartCellCalculator` recomputes grid.

**Testability:** All services are pure functions / enums with zero environment dependencies. Tests pass an explicit `Calendar` and `TimeZone` (`Asia/Tokyo`) so date arithmetic is deterministic. `DataStore.inMemory()` returns an in-memory container if a test ever needs to exercise SwiftData CRUD.

**Project generation:** Xcode project is generated from `project.yml` via `xcodegen`. Edit `project.yml` when changing build settings; **always run `xcodegen generate` after adding new source files or test files** — otherwise the new files won't be compiled and tests/build will fail with "Cannot find ... in scope" errors that look like real bugs.

## SwiftData + CloudKit constraints (non-obvious)

CloudKit imposes schema rules that SwiftData doesn't enforce at compile time. Violations crash at first launch:

1. **No `@Attribute(.unique)`** — CloudKit doesn't support unique constraints. Use SwiftData's implicit `persistentModelID` for uniqueness.
2. **All non-optional `@Model` properties need property-level defaults** — i.e. `var x: Int = 0`, not `var x: Int` (init defaults don't count). For `Date`, use `Date.distantPast` as a sentinel; for `UUID`, use `= UUID()`.
3. **Detect iCloud account before enabling CloudKit** — `FileManager.default.ubiquityIdentityToken != nil`. Without this check, the simulator (and any signed-out device) hard-crashes inside the CloudKit framework before `try ModelContainer(...)` can throw.

## Common pitfalls in this codebase

- **`Range<Date>` traps if upper < lower.** When folding sessions into chart cells, always guard `bedInAt < bedEnd` and `asleepAt < awakeAt` before constructing `..<` ranges. The crash surfaces as `Fatal error: Range requires lowerBound <= upperBound` deep in the SwiftUI render pass.
- **`@MainActor` static methods can't be called from non-isolated tests.** If a service method is provably pure, mark it `nonisolated` (see `PDFExporter.pages(totalDays:)`).
- **Time-ordering invariants must be UI-enforced.** Both `DayEditSheet` and `MorningCorrectionSheet` go through `SleepRecordValidator` and disable the Save button when invalid. New edit surfaces should do the same.
- **`navigationTitle(_:formatter:)` doesn't exist on SwiftUI View** (it's a UINavigationItem API). Use `navigationTitle(formatter.string(from: date))`.
- **`xcodegen` captures the file list at generation time.** Adding a new `.swift` file means `xcodegen generate` before the next build/test.

## Reference docs

- Spec: `docs/superpowers/specs/2026-05-04-sleep-rhythm-chart-design.md`
- Plan: `docs/superpowers/plans/2026-05-04-sleep-rhythm-chart.md`
