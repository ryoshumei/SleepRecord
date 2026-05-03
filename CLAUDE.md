# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

**Regenerate Xcode project from YAML:**
```bash
xcodegen generate
```

**Build:**
```bash
xcodebuild -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

**Run all tests:**
```bash
xcodebuild -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO test
```

**Run a single test class:**
```bash
xcodebuild -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO test \
  -only-testing:SleepRecordTests/ChartCellCalculatorTests
```

**Note:** Xcode 26.x may require a one-time `sudo xcodebuild -runFirstLaunch` before builds succeed. Use `swiftc` for quick syntax checks if the full build toolchain isn't initialized.

## Architecture

**Stack:** SwiftUI + SwiftData, iOS 26.4+, no third-party dependencies. All UI strings are in Japanese.

**Three-layer MVVM + State Machine:**

- **Models/** — `SleepSession` is the only SwiftData `@Model`. It holds four optional timestamps (`bedInAt`, `asleepAt`, `awakeAt`, `bedOutAt`). An in-progress session has `bedOutAt == nil`.

- **Services/** — Pure logic, no SwiftUI dependencies:
  - `DataStore` — singleton `ModelContainer` that tries CloudKit (`iCloud.com.ryan.sleeprecord`) and falls back to local SQLite for development.
  - `SleepStateMachine` — enum with four states (`.empty`, `.inBed`, `.correctionPending`, `.completed`) computed from a session; drives HomeView button labels.
  - `ChartCellCalculator` — converts sessions into a 24-column boolean grid (one row per calendar day) for chart and PDF rendering. Handles overnight sessions that cross date boundaries.
  - `BackfillDetector` — detects when the user skipped the bedtime tap and suggests a default bed time of the previous day at 23:00.
  - `PDFExporter` — renders the traditional 睡眠リズム表 (sleep rhythm chart) at 35 days per page using PDFKit; page-splits are tested in `PDFLayoutBuilderTests`.

- **Views/** — four tabs/sections: `Home` (2-tap UX: night 🌙 → morning ☀️ → correction sheet), `Chart` (monthly grid via `ChartCellCalculator`), `Settings` (notification scheduler, iCloud status), `PDF` (range picker + `PDFKit` preview).

**Data flow:** User tap → modify `SleepSession` in `ModelContext` → SwiftData persists → `@Query` refreshes views → `SleepStateMachine` recomputes button state → `ChartCellCalculator` recomputes grid.

**Testability:** `SleepStateMachine`, `ChartCellCalculator`, and `BackfillDetector` are pure functions/enums with zero environment dependencies. Tests use the in-memory `DataStore.makeTestContainer()`. All calendar logic accepts an explicit `TimeZone` parameter (tests use `Asia/Tokyo`).

**Project generation:** The Xcode project is generated from `project.yml` via `xcodegen`. Edit `project.yml` when adding new source files or changing build settings—do not manually edit `.xcodeproj`.
