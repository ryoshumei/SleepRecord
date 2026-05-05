# Mid-sleep Awakening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `WakeEvent` records to `SleepSession`, drive them from a tap-based "目覚めた / 再び眠る" UI, suppress the chart's asleep hatch on cells overlapping wake events, and surface a `覚醒×N (M分)` summary in the notes column.

**Architecture:** New SwiftData `@Model WakeEvent` with cascade-delete relationship to `SleepSession`. `ChartCellCalculator.cells()` extended to subtract wake-event ranges from the asleep flag (no new visual cell state — bookend-awake cells and mid-sleep awakening cells render identically). `SleepStateMachine` gets a derived `isAwakeMidSleep(activeSession:)` predicate; `HomeView` branches on it inside the existing `.inBed` state. Morning/Day edit sheets gain a "中途覚醒" section with editable rows.

**Tech Stack:** SwiftData + CloudKit (additive schema), SwiftUI, String Catalog (xcstrings), XCTest.

**Spec reference:** `docs/superpowers/specs/2026-05-05-mid-sleep-awakening-design.md`

**Mockup:** `docs/superpowers/mockups/2026-05-05-mid-sleep-awakening-chart.html`

**Build / test invocations:**

```bash
xcodegen generate

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test
```

---

## File map

| File | Change |
|---|---|
| `SleepRecord/Models/WakeEvent.swift` | Create. `@Model` with id, startedAt, endedAt?, session?, createdAt, updatedAt. |
| `SleepRecord/Models/SleepSession.swift` | Modify. Add `@Relationship(deleteRule: .cascade, inverse: \WakeEvent.session) var wakeEvents: [WakeEvent] = []`. |
| `SleepRecord/Services/SleepStateMachine.swift` | Modify. Add `isAwakeMidSleep(activeSession:)` predicate. |
| `SleepRecord/Services/SleepRecordValidator.swift` | Modify. Add 3 new `Issue` cases, `validateWakeEvents` function, message branches. |
| `SleepRecord/Services/ChartCellCalculator.swift` | Modify. Extend `cells()` to subtract wake-event ranges from `asleep`. Extend `notes()` to prepend `覚醒×N (M分)` summary. |
| `SleepRecord/Views/Home/HomeView.swift` | Modify. Add secondary "目覚めた" button below `おはよう`; switch big button to "再び眠る" while open event exists; auto-close all open events on `おはよう`. |
| `SleepRecord/Views/Home/MorningCorrectionSheet.swift` | Modify. Add "中途覚醒" section (rows with start/end DatePickers + delete + add). |
| `SleepRecord/Views/Chart/DayEditSheet.swift` | Modify. Same "中途覚醒" section pattern. |
| `SleepRecord/Localizable.xcstrings` | Modify. +13 keys (per spec §8). |
| `SleepRecordTests/WakeEventTests.swift` | Create. 3 cases. |
| `SleepRecordTests/ChartCellCalculatorTests.swift` | Modify. +3 cases. |
| `SleepRecordTests/SleepStateMachineTests.swift` | Modify. +1 case. |
| `SleepRecordTests/SleepRecordValidatorTests.swift` | Modify. +3 cases. |
| `SleepRecordTests/LocalizationCoverageTests.swift` | Modify. +3 cases. |

`project.yml` — no change (recursive sources). Run `xcodegen generate` whenever a new `.swift` file is added.

---

## Task 1: Schema — `WakeEvent` model + `SleepSession` relationship

**Files:**
- Create: `SleepRecord/Models/WakeEvent.swift`
- Modify: `SleepRecord/Models/SleepSession.swift`

- [ ] **Step 1: Create `SleepRecord/Models/WakeEvent.swift`**

```swift
import Foundation
import SwiftData

@Model
final class WakeEvent {
    // CloudKit requires all non-optional attributes to have property-level defaults.
    var id: UUID = UUID()
    var startedAt: Date = Date.distantPast
    var endedAt: Date?            // nil = still awake (open event)
    var session: SleepSession?    // CloudKit-friendly optional inverse
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        session: SleepSession? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.session = session
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isOpen: Bool { endedAt == nil }

    /// Duration in minutes; nil for open events.
    var durationMinutes: Int? {
        guard let end = endedAt, end > startedAt else { return nil }
        return Int(end.timeIntervalSince(startedAt) / 60)
    }
}
```

- [ ] **Step 2: Add the inverse relationship to `SleepSession.swift`**

In `SleepRecord/Models/SleepSession.swift`, just before the closing `}` of the `@Model class SleepSession`, after the `isFullyRecorded` computed property (line 37), insert:

```swift
    @Relationship(deleteRule: .cascade, inverse: \WakeEvent.session)
    var wakeEvents: [WakeEvent] = []
```

The result around line 36–40 should read:

```swift
    var isInProgress: Bool { bedOutAt == nil }
    var isFullyRecorded: Bool { bedOutAt != nil && asleepAt != nil && awakeAt != nil }

    @Relationship(deleteRule: .cascade, inverse: \WakeEvent.session)
    var wakeEvents: [WakeEvent] = []
}
```

- [ ] **Step 3: Regenerate Xcode project**

Run: `xcodegen generate`
Expected: `Created project at SleepRecord.xcodeproj`.

- [ ] **Step 4: Build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Run tests (regression — should still be 46)**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Expected: `Executed 46 tests, with 0 failures` and `** TEST SUCCEEDED **`. Existing data continues to load — `wakeEvents` defaults to empty for existing sessions.

- [ ] **Step 6: Commit (includes spec + plan + mockup)**

```bash
git add SleepRecord/Models/WakeEvent.swift \
        SleepRecord/Models/SleepSession.swift \
        SleepRecord.xcodeproj/project.pbxproj \
        docs/superpowers/specs/2026-05-05-mid-sleep-awakening-design.md \
        docs/superpowers/plans/2026-05-05-mid-sleep-awakening.md \
        docs/superpowers/mockups/2026-05-05-mid-sleep-awakening-chart.html
git commit -m "$(cat <<'EOF'
中途覚醒: add WakeEvent SwiftData model + SleepSession relationship

New @Model WakeEvent (id, startedAt, endedAt?, session?, createdAt,
updatedAt) with cascade-delete relationship from SleepSession. Schema
is additive — existing v1 records load with wakeEvents = []. CloudKit
constraints respected (property defaults, no .unique). Spec, plan, and
HTML mockup committed alongside the code.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds.

---

## Task 2: `SleepStateMachine.isAwakeMidSleep` + `WakeEventTests`

**Files:**
- Modify: `SleepRecord/Services/SleepStateMachine.swift`
- Create: `SleepRecordTests/WakeEventTests.swift`
- Modify: `SleepRecordTests/SleepStateMachineTests.swift`

- [ ] **Step 1: Write the failing tests for `WakeEvent` first**

Path: `SleepRecordTests/WakeEventTests.swift`

```swift
import XCTest
@testable import SleepRecord

final class WakeEventTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    let tz = TimeZone(identifier: "Asia/Tokyo")!

    func dt(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        c.timeZone = tz
        return cal.date(from: c)!
    }

    func testOpen_WhenEndedAtIsNil() {
        let e = WakeEvent(startedAt: dt(2026, 5, 5, 3, 0))
        XCTAssertTrue(e.isOpen)
        XCTAssertNil(e.durationMinutes)
    }

    func testClosed_DurationIsCorrect() {
        let e = WakeEvent(
            startedAt: dt(2026, 5, 5, 3, 0),
            endedAt: dt(2026, 5, 5, 3, 30)
        )
        XCTAssertFalse(e.isOpen)
        XCTAssertEqual(e.durationMinutes, 30)
    }

    func testClosed_InvertedTimes_DurationNil() {
        // Defensive: endedAt before startedAt should not crash and should be
        // surfaced as nil duration so UI can avoid showing nonsense.
        let e = WakeEvent(
            startedAt: dt(2026, 5, 5, 3, 30),
            endedAt: dt(2026, 5, 5, 3, 0)
        )
        XCTAssertFalse(e.isOpen)
        XCTAssertNil(e.durationMinutes)
    }
}
```

- [ ] **Step 2: Add the new `SleepStateMachine` test**

In `SleepRecordTests/SleepStateMachineTests.swift`, append (before the closing `}`):

```swift
    func testIsAwakeMidSleep_TrueWhenOpenWakeEventExists() {
        let session = SleepSession(bedInAt: .now)
        session.wakeEvents.append(WakeEvent(startedAt: .now, session: session))
        XCTAssertTrue(SleepStateMachine.isAwakeMidSleep(activeSession: session))
    }

    func testIsAwakeMidSleep_FalseWhenAllEventsClosed() {
        let session = SleepSession(bedInAt: .now)
        session.wakeEvents.append(WakeEvent(
            startedAt: .now, endedAt: .now.addingTimeInterval(60), session: session
        ))
        XCTAssertFalse(SleepStateMachine.isAwakeMidSleep(activeSession: session))
    }
```

(Note: §9.1 budget said +1 case; we're at +2 small ones because both branches deserve coverage. Total still well within budget.)

- [ ] **Step 3: Add the predicate to `SleepStateMachine.swift`**

In `SleepRecord/Services/SleepStateMachine.swift`, append before the closing `}` of the `enum SleepStateMachine` block (after `static func state(...)`):

```swift
    /// True iff the active session has at least one open WakeEvent (i.e. user
    /// tapped 目覚めた but hasn't tapped 再び眠る yet).
    static func isAwakeMidSleep(activeSession: SleepSession?) -> Bool {
        guard let s = activeSession else { return false }
        return s.wakeEvents.contains { $0.isOpen }
    }
```

- [ ] **Step 4: Regenerate project (new test file)**

Run: `xcodegen generate`
Expected: `Created project at SleepRecord.xcodeproj`.

- [ ] **Step 5: Run tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Expected: `Executed 51 tests, with 0 failures`. (46 + 3 WakeEvent + 2 state machine = 51.)

- [ ] **Step 6: Commit**

```bash
git add SleepRecord/Services/SleepStateMachine.swift \
        SleepRecordTests/WakeEventTests.swift \
        SleepRecordTests/SleepStateMachineTests.swift \
        SleepRecord.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
中途覚醒: SleepStateMachine.isAwakeMidSleep + WakeEvent tests

Predicate is true iff the active session has at least one open
WakeEvent (endedAt == nil). HomeView will branch on this inside the
existing .inBed state. 5 new test cases (3 WakeEvent + 2 state machine).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `SleepRecordValidator` extension + xcstrings keys + LocalizationCoverageTests

**Files:**
- Modify: `SleepRecord/Services/SleepRecordValidator.swift`
- Modify: `SleepRecord/Localizable.xcstrings`
- Modify: `SleepRecordTests/SleepRecordValidatorTests.swift`
- Modify: `SleepRecordTests/LocalizationCoverageTests.swift`

- [ ] **Step 1: Add 3 new `Issue` cases**

In `SleepRecord/Services/SleepRecordValidator.swift`, replace the `enum Issue` block (lines 11–16) with:

```swift
    enum Issue: Equatable {
        case bedWindowInverted          // bedInAt >= bedOutAt
        case asleepBeforeBedIn          // asleepAt < bedInAt
        case awakeAfterBedOut           // awakeAt > bedOutAt
        case asleepAfterAwake           // asleepAt > awakeAt
        case wakeEventOutOfBounds       // wake event start or end outside [bedInAt, bedOutAt]
        case wakeEventOverlap           // two wake events have overlapping ranges
        case wakeEventInverted          // wake event endedAt <= startedAt
    }
```

- [ ] **Step 2: Add `validateWakeEvents` static function**

In the same file, inside `enum SleepRecordValidator { ... }`, after `validateSleepOnly` (around line 45), append:

```swift
    /// Validates a list of (startedAt, endedAt?) wake events against the bed
    /// window. Returns the first issue found, or nil if all events are OK.
    /// Open events (endedAt == nil) are accepted as long as startedAt is in bounds.
    static func validateWakeEvents(
        _ events: [(startedAt: Date, endedAt: Date?)],
        bedInAt: Date,
        bedOutAt: Date
    ) -> Issue? {
        let upper = bedOutAt
        for e in events {
            // 1. start in bounds (>= bedInAt and <= bedOutAt)
            if e.startedAt < bedInAt || e.startedAt > upper {
                return .wakeEventOutOfBounds
            }
            if let end = e.endedAt {
                // 2. end in bounds
                if end < bedInAt || end > upper {
                    return .wakeEventOutOfBounds
                }
                // 3. ordering
                if end <= e.startedAt {
                    return .wakeEventInverted
                }
            }
        }
        // 4. overlap (compare every pair)
        let closed = events.compactMap { e -> (Date, Date)? in
            guard let end = e.endedAt, end > e.startedAt else { return nil }
            return (e.startedAt, end)
        }
        for i in 0..<closed.count {
            for j in (i + 1)..<closed.count {
                let a = closed[i], b = closed[j]
                if a.0 < b.1 && b.0 < a.1 { return .wakeEventOverlap }
            }
        }
        return nil
    }
```

- [ ] **Step 3: Extend the message extension with 3 new cases**

In the same file, in the `extension SleepRecordValidator.Issue { func message(...) }` switch (around line 50), append three new cases right before the closing brace of the switch:

```swift
        case .wakeEventOutOfBounds:
            return String(
                localized: "validator.wakeEventOutOfBounds",
                defaultValue: "中途覚醒の時刻は入床〜起床の範囲内に収めてください"
            )
        case .wakeEventOverlap:
            return String(
                localized: "validator.wakeEventOverlap",
                defaultValue: "中途覚醒の時間が他のイベントと重なっています"
            )
        case .wakeEventInverted:
            return String(
                localized: "validator.wakeEventInverted",
                defaultValue: "中途覚醒の終了時刻は開始時刻より後である必要があります"
            )
```

- [ ] **Step 4: Add the 3 new keys to `Localizable.xcstrings`**

In `SleepRecord/Localizable.xcstrings`, in the `"strings"` object (after the existing `validator.*` block), insert:

```json
    "validator.wakeEventOutOfBounds" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "中途覚醒の時刻は入床〜起床の範囲内に収めてください" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Mid-sleep awakening must fall within the bed window" } }
    } },
    "validator.wakeEventOverlap" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "中途覚醒の時間が他のイベントと重なっています" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Mid-sleep awakenings cannot overlap" } }
    } },
    "validator.wakeEventInverted" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "中途覚醒の終了時刻は開始時刻より後である必要があります" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Awakening end must be after start" } }
    } },
```

- [ ] **Step 5: Add 3 cases to `SleepRecordValidatorTests.swift`**

Append (before the final `}`):

```swift
    // MARK: validateWakeEvents

    func testValidateWakeEvents_OutOfBounds_StartBeforeBedIn() {
        let r = SleepRecordValidator.validateWakeEvents(
            [(startedAt: dt(2026, 5, 4, 22, 0), endedAt: dt(2026, 5, 4, 22, 30))],
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0)
        )
        XCTAssertEqual(r, .wakeEventOutOfBounds)
    }

    func testValidateWakeEvents_Overlap() {
        let r = SleepRecordValidator.validateWakeEvents(
            [
                (startedAt: dt(2026, 5, 5, 1, 0), endedAt: dt(2026, 5, 5, 1, 30)),
                (startedAt: dt(2026, 5, 5, 1, 15), endedAt: dt(2026, 5, 5, 1, 45))
            ],
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0)
        )
        XCTAssertEqual(r, .wakeEventOverlap)
    }

    func testValidateWakeEvents_Inverted() {
        let r = SleepRecordValidator.validateWakeEvents(
            [(startedAt: dt(2026, 5, 5, 3, 30), endedAt: dt(2026, 5, 5, 3, 0))],
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0)
        )
        XCTAssertEqual(r, .wakeEventInverted)
    }
```

- [ ] **Step 6: Add 3 LocalizationCoverageTests**

In `SleepRecordTests/LocalizationCoverageTests.swift`, append before the final `}`:

```swift
    func testValidator_WakeEventOutOfBounds_HasEnglish() {
        assertEnglish("validator.wakeEventOutOfBounds")
    }

    func testValidator_WakeEventOverlap_HasEnglish() {
        assertEnglish("validator.wakeEventOverlap")
    }

    func testValidator_WakeEventInverted_HasEnglish() {
        assertEnglish("validator.wakeEventInverted")
    }
```

- [ ] **Step 7: Run tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Expected: `Executed 57 tests, with 0 failures`. (51 + 3 validator + 3 coverage = 57.)

- [ ] **Step 8: Commit**

```bash
git add SleepRecord/Services/SleepRecordValidator.swift \
        SleepRecord/Localizable.xcstrings \
        SleepRecordTests/SleepRecordValidatorTests.swift \
        SleepRecordTests/LocalizationCoverageTests.swift
git commit -m "$(cat <<'EOF'
中途覚醒: SleepRecordValidator + 3 wake-event Issue cases

New cases: wakeEventOutOfBounds, wakeEventOverlap, wakeEventInverted.
validateWakeEvents() returns the first violating issue. Three EN+JA
catalog keys added; LocalizationCoverageTests grow by 3 to lock the EN
translations in.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `ChartCellCalculator` extension + 3 tests + 2 xcstrings (summary keys)

**Files:**
- Modify: `SleepRecord/Services/ChartCellCalculator.swift`
- Modify: `SleepRecord/Localizable.xcstrings`
- Modify: `SleepRecordTests/ChartCellCalculatorTests.swift`

- [ ] **Step 1: Add the 3 chart tests first (TDD — they should fail until step 3 lands)**

Append in `SleepRecordTests/ChartCellCalculatorTests.swift` before the final `}`:

```swift
    // MARK: wake events

    func testCells_WakeEventSuppressesAsleep() {
        let s = SleepSession(
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0),
            asleepAt: dt(2026, 5, 4, 23, 30),
            awakeAt: dt(2026, 5, 5, 6, 30)
        )
        // 3:00–3:30 wake event — hour 3 cell should be in-bed but NOT asleep.
        let event = WakeEvent(
            startedAt: dt(2026, 5, 5, 3, 0),
            endedAt: dt(2026, 5, 5, 3, 30),
            session: s
        )
        s.wakeEvents = [event]

        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let cells = calc.cells(forDay: dt(2026, 5, 5, 0, 0), sessions: [s])

        XCTAssertTrue(cells[3].inBed)
        XCTAssertFalse(cells[3].asleep, "wake event should suppress asleep on hour 3")
        // hour 2 unaffected
        XCTAssertTrue(cells[2].inBed)
        XCTAssertTrue(cells[2].asleep)
    }

    func testCells_MultipleWakeEvents() {
        let s = SleepSession(
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0),
            asleepAt: dt(2026, 5, 4, 23, 30),
            awakeAt: dt(2026, 5, 5, 6, 30)
        )
        s.wakeEvents = [
            WakeEvent(startedAt: dt(2026, 5, 5, 1, 0),
                      endedAt:   dt(2026, 5, 5, 1, 15), session: s),
            WakeEvent(startedAt: dt(2026, 5, 5, 4, 0),
                      endedAt:   dt(2026, 5, 5, 4, 45), session: s)
        ]
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let cells = calc.cells(forDay: dt(2026, 5, 5, 0, 0), sessions: [s])

        XCTAssertFalse(cells[1].asleep)
        XCTAssertFalse(cells[4].asleep)
        XCTAssertTrue(cells[3].asleep, "no event in hour 3 — should still be asleep")
        XCTAssertTrue(cells[2].asleep, "no event in hour 2")
    }

    func testNotes_PrependsSummary() {
        let s = SleepSession(
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0),
            asleepAt: dt(2026, 5, 4, 23, 30),
            awakeAt: dt(2026, 5, 5, 6, 30),
            notes: "夜中トイレ"
        )
        s.wakeEvents = [
            WakeEvent(startedAt: dt(2026, 5, 5, 3, 0),
                      endedAt:   dt(2026, 5, 5, 3, 30), session: s)
        ]
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let result = calc.notes(forDay: dt(2026, 5, 5, 0, 0), sessions: [s])
        XCTAssertTrue(result.contains("覚醒×1") || result.contains("Wakes×1"))
        XCTAssertTrue(result.contains("30"), "summary should mention 30 minutes")
        XCTAssertTrue(result.contains("夜中トイレ"))
    }
```

(`cal` and `tz` are declared at the top of the existing test file at lines 5–6; reuse them.)

- [ ] **Step 2: Verify tests fail**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | grep "fail" | head -5
```

Expected: 3 failures in the new tests (assertions for asleep=false and summary substring fail because the calculator hasn't been extended yet).

- [ ] **Step 3: Extend `ChartCellCalculator.cells()`**

In `SleepRecord/Services/ChartCellCalculator.swift`, replace the body of `cells(forDay:sessions:)` (lines 25–65) with:

```swift
    func cells(forDay day: Date, sessions: [SleepSession]) -> [ChartCell] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return Array(repeating: .empty, count: 24)
        }

        var cells = Array(repeating: ChartCell.empty, count: 24)

        for session in sessions {
            // Build ranges defensively. Swift crashes on Range where upper < lower,
            // which can happen if (a) the session's bed/sleep window doesn't include
            // this day at all (bedInAt > dayEnd), or (b) user data is out of order
            // (e.g., correction sheet defaults make asleepAt > awakeAt for very short
            // sessions). Skip such ranges instead of crashing.
            let bedEnd = session.bedOutAt ?? dayEnd
            guard session.bedInAt < bedEnd else { continue }
            let bedRange = session.bedInAt..<bedEnd

            let sleepRange: Range<Date>? = {
                guard let s = session.asleepAt, let e = session.awakeAt, s < e else { return nil }
                return s..<e
            }()

            // Wake events: each closed event is [start, end); open events use
            // [start, max(start, now)] so they show as red gaps for the
            // in-progress day. Defensive guard prevents trapping ranges.
            let wakeRanges: [Range<Date>] = session.wakeEvents.compactMap { e in
                let end = e.endedAt ?? max(e.startedAt, .now)
                guard e.startedAt < end else { return nil }
                return e.startedAt..<end
            }

            for hour in 0..<24 {
                guard let cellStart = calendar.date(byAdding: .hour, value: hour, to: dayStart),
                      let cellEnd = calendar.date(byAdding: .hour, value: hour + 1, to: dayStart)
                else { continue }
                let cellRange = cellStart..<cellEnd

                let bedOverlap = rangesOverlap(bedRange, cellRange)
                let sleepOverlapRaw = sleepRange.map { rangesOverlap($0, cellRange) } ?? false
                let wakeOverlap = wakeRanges.contains { rangesOverlap($0, cellRange) }
                let sleepOverlap = sleepOverlapRaw && !wakeOverlap

                if bedOverlap || sleepOverlap {
                    cells[hour] = ChartCell(
                        inBed: cells[hour].inBed || bedOverlap,
                        asleep: cells[hour].asleep || sleepOverlap
                    )
                }
            }
        }
        return cells
    }
```

- [ ] **Step 4: Extend `ChartCellCalculator.notes()` to prepend the summary**

In the same file, replace the body of `notes(forDay:sessions:)` (lines 74–85) with:

```swift
    func notes(forDay day: Date, sessions: [SleepSession]) -> String {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return "" }
        let parts: [String] = sessions
            .filter { s in
                let anchor = s.bedOutAt ?? s.bedInAt
                return anchor >= dayStart && anchor < dayEnd
            }
            .map { s in
                var pieces: [String] = []
                if !s.wakeEvents.isEmpty {
                    pieces.append(Self.wakeSummary(for: s.wakeEvents))
                }
                if !s.notes.isEmpty {
                    pieces.append(s.notes)
                }
                return pieces.joined(separator: " ")
            }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " / ")
    }

    private static func wakeSummary(for events: [WakeEvent]) -> String {
        let count = events.count
        let hasOpen = events.contains { $0.isOpen }
        if hasOpen {
            return String(
                localized: "wake.summary.open",
                defaultValue: "覚醒×\(count) (進行中)"
            )
        }
        let totalMin = events.reduce(0) { acc, e in acc + (e.durationMinutes ?? 0) }
        return String(
            localized: "wake.summary",
            defaultValue: "覚醒×\(count) (\(totalMin)分)"
        )
    }
```

- [ ] **Step 5: Add the 2 summary keys to `Localizable.xcstrings`**

Insert in `SleepRecord/Localizable.xcstrings` (`"strings"` object), near the other PDF/chart keys:

```json
    "wake.summary" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "覚醒×%1$d (%2$d分)" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Wakes×%1$d (%2$dm)" } }
    } },
    "wake.summary.open" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "覚醒×%1$d (進行中)" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Wakes×%1$d (open)" } }
    } },
```

(The `\(count)` and `\(totalMin)` interpolations in `String(localized:defaultValue:)` produce `%1$d` and `%2$d` placeholders in the catalog lookup. The catalog values must use those positional forms.)

- [ ] **Step 6: Run tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Expected: `Executed 60 tests, with 0 failures`. (57 + 3 chart cells = 60.)

- [ ] **Step 7: Commit**

```bash
git add SleepRecord/Services/ChartCellCalculator.swift \
        SleepRecord/Localizable.xcstrings \
        SleepRecordTests/ChartCellCalculatorTests.swift
git commit -m "$(cat <<'EOF'
中途覚醒: ChartCellCalculator subtracts wake events from asleep + summary

cells(forDay:) now suppresses the asleep flag on any hour cell that
overlaps a closed WakeEvent (or [start, now] for open events on the
in-progress day). notes(forDay:) prepends 覚醒×N (M分) / Wakes×N (Mm)
when events exist; open events render as 覚醒×N (進行中) / Wakes×N (open).
Three new chart tests; two new catalog keys.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: HomeView UI — secondary 目覚めた button + 再び眠る switch + elapsed timer

**Files:**
- Modify: `SleepRecord/Views/Home/HomeView.swift`
- Modify: `SleepRecord/Localizable.xcstrings`

- [ ] **Step 1: Add 5 new keys to `Localizable.xcstrings`**

Insert in the catalog (`"strings"` object):

```json
    "目覚めた" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "目覚めた" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Woke up" } }
    } },
    "再び眠る" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "再び眠る" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Back to sleep" } }
    } },
    "wake.elapsed.minutesUnder1" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "目覚めて 1分未満" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Awake for under 1m" } }
    } },
    "wake.elapsed.minutes" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "目覚めて %d分" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Awake for %dm" } }
    } },
    "wake.elapsed.hoursMinutes" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "目覚めて %1$d時間%2$d分" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Awake for %1$dh %2$dm" } }
    } },
```

- [ ] **Step 2: Add the wake-event helper methods to `HomeView.swift`**

In `SleepRecord/Views/Home/HomeView.swift`, after the existing helper methods (around line 167, between `tapMorning` and `autoPresentCorrectionIfNeeded`), insert:

```swift
    private func tapWokeUp() {
        guard let s = activeSession else { return }
        let event = WakeEvent(startedAt: now, session: s)
        modelContext.insert(event)
        s.wakeEvents.append(event)
        s.updatedAt = now
        try? modelContext.save()
    }

    private func tapBackToSleep() {
        guard let s = activeSession else { return }
        if let openEvent = s.wakeEvents.first(where: { $0.isOpen }) {
            openEvent.endedAt = now
            openEvent.updatedAt = now
            s.updatedAt = now
            try? modelContext.save()
        }
    }

    /// Closes any open wake events; called from tapMorning before existing logic runs.
    private func closeOpenWakeEventsForMorning() {
        guard let s = activeSession else { return }
        var dirty = false
        for event in s.wakeEvents where event.isOpen {
            event.endedAt = now
            event.updatedAt = now
            dirty = true
        }
        if dirty {
            s.updatedAt = now
            try? modelContext.save()
        }
    }

    private func elapsedSinceWokeUp() -> LocalizedStringKey {
        guard let s = activeSession,
              let openEvent = s.wakeEvents.first(where: { $0.isOpen })
        else { return "" }
        let secs = Int(now.timeIntervalSince(openEvent.startedAt))
        let totalMin = max(0, secs / 60)
        if totalMin < 1 {
            return "wake.elapsed.minutesUnder1"
        }
        if totalMin < 60 {
            return LocalizedStringKey("wake.elapsed.minutes \(totalMin)")
        }
        let h = totalMin / 60
        let m = totalMin % 60
        return LocalizedStringKey("wake.elapsed.hoursMinutes \(h) \(m)")
    }
```

- [ ] **Step 3: Wire `tapMorning` to auto-close open wake events**

In `HomeView.swift`, modify `tapMorning()` (around line 147) — insert one line at the very top:

```swift
    private func tapMorning() {
        closeOpenWakeEventsForMorning()
        guard let s = activeSession else {
            let result = BackfillDetector.detect(now: now, activeSession: nil)
            backfillSuggested = result.suggestedBedInAt ?? now
            showBackfillSheet = true
            return
        }
        s.bedOutAt = now
        s.updatedAt = now
        try? modelContext.save()
        showCorrectionSheet = true
    }
```

- [ ] **Step 4: Branch the `.inBed` case of `bigButton`**

In `HomeView.swift`, locate the `.inBed:` case in `bigButton` (around line 93). Replace just that case with a sub-branch:

```swift
        case .inBed:
            if SleepStateMachine.isAwakeMidSleep(activeSession: activeSession) {
                Button(action: tapBackToSleep) {
                    buttonShape(
                        emoji: "🛏️", title: "再び眠る",
                        subtitle: elapsedSinceWokeUp(),
                        colors: [Color(red: 0.36, green: 0.13, blue: 0.71), Color.purple]
                    )
                }
            } else {
                Button(action: tapMorning) {
                    buttonShape(
                        emoji: "☀️", title: "おはよう",
                        subtitle: "タップで起床時刻を記録",
                        colors: [Color.orange, Color(red: 0.96, green: 0.62, blue: 0.04)]
                    )
                }
            }
```

- [ ] **Step 5: Add the secondary "目覚めた" button below the big button**

In `HomeView.swift`'s `body` block, locate the `bigButton` placement inside the main `VStack` (around line 45 — `bigButton` followed by the optional in-bed text). After `bigButton` and the conditional `if case .inBed = state, let s = activeSession { Text(...) }` block, insert the secondary button:

```swift
                    if case .inBed = state {
                        if SleepStateMachine.isAwakeMidSleep(activeSession: activeSession) {
                            Button("☀️ おはよう") { tapMorning() }
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.top, 32)
                        } else {
                            Button("🌗 目覚めた") { tapWokeUp() }
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.top, 32)
                        }
                    }
```

The button labels are passed as string literals so SwiftUI auto-applies `LocalizedStringKey`.

- [ ] **Step 6: Confirm `buttonShape` already accepts `LocalizedStringKey` for subtitle**

`buttonShape` was previously updated in the i18n branch to take `LocalizedStringKey` for both `title` and `subtitle` (commit `df30d84`). No change needed — the `elapsedSinceWokeUp()` return type already matches.

- [ ] **Step 7: Build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Run tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Expected: `Executed 60 tests, with 0 failures` (no new tests in this task — UI is verified visually in Task 8).

- [ ] **Step 9: Commit**

```bash
git add SleepRecord/Views/Home/HomeView.swift \
        SleepRecord/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
中途覚醒: HomeView 目覚めた / 再び眠る tap flow

In .inBed state, a small "🌗 目覚めた" button appears below the big
おはよう button. Tapping it creates an open WakeEvent and switches the
big button to "🛏️ 再び眠る" with a live "目覚めて N分" subtitle.
Tapping おはよう (small) or 再び眠る (big) closes the open event;
おはよう also auto-closes any open events as part of the morning flow.
Five new catalog keys for the button labels and elapsed timer.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `MorningCorrectionSheet` — 中途覚醒 section

**Files:**
- Modify: `SleepRecord/Views/Home/MorningCorrectionSheet.swift`
- Modify: `SleepRecord/Localizable.xcstrings`

- [ ] **Step 1: Add 3 new keys to `Localizable.xcstrings`**

```json
    "中途覚醒" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "中途覚醒" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Mid-sleep awakenings" } }
    } },
    "（なし）" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "（なし）" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "(none)" } }
    } },
    "追加" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "追加" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Add" } }
    } },
```

- [ ] **Step 2: Extend `validationError` in `MorningCorrectionSheet`**

In `SleepRecord/Views/Home/MorningCorrectionSheet.swift`, replace the `validationError` computed property (around line 43) with:

```swift
    private var validationError: String? {
        if let timeIssue = SleepRecordValidator.validate(
            bedInAt: bedInAt, bedOutAt: bedOutAt,
            asleepAt: asleepAt, awakeAt: awakeAt
        ) {
            return timeIssue.message(bedInAt: bedInAt, bedOutAt: bedOutAt)
        }
        let events = session.wakeEvents.map {
            (startedAt: $0.startedAt, endedAt: $0.endedAt)
        }
        if let wakeIssue = SleepRecordValidator.validateWakeEvents(
            events, bedInAt: bedInAt, bedOutAt: bedOutAt
        ) {
            return wakeIssue.message()
        }
        return nil
    }
```

- [ ] **Step 3: Insert the 中途覚醒 section into the form**

In the same file, locate the `Section("備考")` (around line 84) and insert this new section **immediately before** it:

```swift
                Section("中途覚醒") {
                    if session.wakeEvents.isEmpty {
                        Text("（なし）")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    } else {
                        ForEach(session.wakeEvents.sorted(by: { $0.startedAt < $1.startedAt })) { event in
                            wakeEventRow(event)
                        }
                    }
                    Button {
                        addWakeEvent()
                    } label: {
                        Label("追加", systemImage: "plus.circle.fill")
                            .font(.footnote)
                    }
                }
```

- [ ] **Step 4: Add the helper methods to `MorningCorrectionSheet`**

In `MorningCorrectionSheet`, after the existing `save()` method (around line 113), append:

```swift
    @ViewBuilder
    private func wakeEventRow(_ event: WakeEvent) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                DatePicker("", selection: Binding(
                    get: { event.startedAt },
                    set: { event.startedAt = $0; event.updatedAt = .now }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                DatePicker("", selection: Binding(
                    get: { event.endedAt ?? event.startedAt },
                    set: { event.endedAt = $0; event.updatedAt = .now }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
            }
            Spacer()
            Button(role: .destructive) {
                deleteWakeEvent(event)
            } label: {
                Image(systemName: "trash")
            }
        }
    }

    private func addWakeEvent() {
        let mid = bedInAt.addingTimeInterval(bedOutAt.timeIntervalSince(bedInAt) / 2)
        let end = mid.addingTimeInterval(10 * 60)  // +10 min default
        let event = WakeEvent(
            startedAt: mid,
            endedAt: end,
            session: session
        )
        modelContext.insert(event)
        session.wakeEvents.append(event)
        session.updatedAt = .now
    }

    private func deleteWakeEvent(_ event: WakeEvent) {
        if let idx = session.wakeEvents.firstIndex(where: { $0.id == event.id }) {
            session.wakeEvents.remove(at: idx)
        }
        modelContext.delete(event)
        session.updatedAt = .now
    }
```

- [ ] **Step 5: Build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Run tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Expected: `Executed 60 tests, with 0 failures`.

- [ ] **Step 7: Commit**

```bash
git add SleepRecord/Views/Home/MorningCorrectionSheet.swift \
        SleepRecord/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
中途覚醒: MorningCorrectionSheet 中途覚醒 section

New section between 覚醒時刻 and 備考 with one row per WakeEvent
(start/end DatePickers + delete) and a "+ 追加" button. Validation now
runs validateWakeEvents() in addition to the existing time-ordering
check; Save is disabled with the appropriate error message. Three new
catalog keys (section header, empty placeholder, add button).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `DayEditSheet` — 中途覚醒 section (same pattern)

**Files:**
- Modify: `SleepRecord/Views/Chart/DayEditSheet.swift`

- [ ] **Step 1: Extend `validationError` to cover wake events**

In `SleepRecord/Views/Chart/DayEditSheet.swift`, replace the `validationError` computed property (around line 20) with:

```swift
    private var validationError: String? {
        if let timeIssue = SleepRecordValidator.validate(
            bedInAt: bedInAt, bedOutAt: bedOutAt,
            asleepAt: asleepAt, awakeAt: awakeAt
        ) {
            return timeIssue.message()
        }
        guard let s = existing else { return nil }
        let events = s.wakeEvents.map { (startedAt: $0.startedAt, endedAt: $0.endedAt) }
        if let wakeIssue = SleepRecordValidator.validateWakeEvents(
            events, bedInAt: bedInAt, bedOutAt: bedOutAt
        ) {
            return wakeIssue.message()
        }
        return nil
    }
```

- [ ] **Step 2: Insert the 中途覚醒 section before "備考"**

Locate `Section("備考")` (around line 43) and insert ABOVE it:

```swift
                if let s = existing {
                    Section("中途覚醒") {
                        if s.wakeEvents.isEmpty {
                            Text("（なし）")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        } else {
                            ForEach(s.wakeEvents.sorted(by: { $0.startedAt < $1.startedAt })) { event in
                                wakeEventRow(event)
                            }
                        }
                        Button {
                            addWakeEvent(to: s)
                        } label: {
                            Label("追加", systemImage: "plus.circle.fill")
                                .font(.footnote)
                        }
                    }
                }
```

(Wrapped in `if let s = existing` because `DayEditSheet` may be opened on a day with no record yet — wake events only attach to existing sessions; if a brand new session is being created, `addWakeEvent` is unavailable until first save.)

- [ ] **Step 3: Add helper methods to `DayEditSheet`**

After the existing `save()` method (around line 117), append:

```swift
    @ViewBuilder
    private func wakeEventRow(_ event: WakeEvent) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                DatePicker("", selection: Binding(
                    get: { event.startedAt },
                    set: { event.startedAt = $0; event.updatedAt = .now }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                DatePicker("", selection: Binding(
                    get: { event.endedAt ?? event.startedAt },
                    set: { event.endedAt = $0; event.updatedAt = .now }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
            }
            Spacer()
            Button(role: .destructive) {
                deleteWakeEvent(event, from: existing)
            } label: {
                Image(systemName: "trash")
            }
        }
    }

    private func addWakeEvent(to session: SleepSession) {
        let mid = bedInAt.addingTimeInterval(bedOutAt.timeIntervalSince(bedInAt) / 2)
        let end = mid.addingTimeInterval(10 * 60)
        let event = WakeEvent(
            startedAt: mid,
            endedAt: end,
            session: session
        )
        modelContext.insert(event)
        session.wakeEvents.append(event)
        session.updatedAt = .now
    }

    private func deleteWakeEvent(_ event: WakeEvent, from session: SleepSession?) {
        guard let session else { return }
        if let idx = session.wakeEvents.firstIndex(where: { $0.id == event.id }) {
            session.wakeEvents.remove(at: idx)
        }
        modelContext.delete(event)
        session.updatedAt = .now
    }
```

- [ ] **Step 4: Build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Run tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Expected: `Executed 60 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add SleepRecord/Views/Chart/DayEditSheet.swift
git commit -m "$(cat <<'EOF'
中途覚醒: DayEditSheet section for retroactive editing

Same row-per-WakeEvent pattern as MorningCorrectionSheet; only visible
when a SleepSession already exists for the day (the "+ 追加" path
needs a session to attach to). Validation routes through the same
SleepRecordValidator.validateWakeEvents call.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Visual smoke test on simulator

No code, no commit. Verifies the integrated tap flow + chart rendering on a real iOS runtime.

- [ ] **Step 1: Boot iPhone 17e (iOS 26.4)**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl boot BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B 2>/dev/null
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl bootstatus BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B -b
```

Expected: `Device already booted, nothing to do.` or completion of boot.

- [ ] **Step 2: Reinstall and launch (Japanese)**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B com.ryan.sleeprecord 2>/dev/null
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl uninstall BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B com.ryan.sleeprecord 2>/dev/null
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl install BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B \
  /Users/ryan/Library/Developer/Xcode/DerivedData/SleepRecord-ddmwrmmbtucbvydtevhibasogwyw/Build/Products/Debug-iphonesimulator/SleepRecord.app
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B com.ryan.sleeprecord -AppleLanguages '("ja")'
```

- [ ] **Step 3: Manually drive the flow on the simulator**

Tap 🌙 おやすみ → wait a moment → confirm "🌗 目覚めた" small button appears below the おはよう big button.

Tap 目覚めた → confirm the big button switches to "🛏️ 再び眠る", subtitle reads "目覚めて 1分未満" then "目覚めて N分".

Wait ~1 minute → tap 再び眠る → confirm the big button switches back to おはよう, secondary "🌗 目覚めた" reappears.

Repeat the wake / back-to-sleep tap once more.

Tap おはよう → correction sheet opens with the 中途覚醒 section showing 2 rows. Confirm the rows have start/end DatePickers and trash buttons. Add one event with the "+" button → confirm a 3rd row appears with default mid-window timing.

Tap キャンセル to dismiss without saving.

Tap おはよう again → correction sheet opens again → tap 確定 → dismiss.

Switch to the チャート tab → confirm today's row shows red gaps where wake events were.

Tap today's row → DayEditSheet opens → confirm the same 中途覚醒 section is visible with the saved events.

- [ ] **Step 4: Switch to English and re-verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B com.ryan.sleeprecord
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B com.ryan.sleeprecord -AppleLanguages '("en")'
```

Confirm: "Woke up", "Back to sleep", "Awake for Nm", "Mid-sleep awakenings" section header all appear in English. PDF preview's notes column shows `Wakes×N (Nm)`.

- [ ] **Step 5: Capture before/after screenshots for the record**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B screenshot /tmp/sleeprecord-mid-sleep-en.png
```

Read the screenshot in this session and confirm the visual matches the mockup at `docs/superpowers/mockups/2026-05-05-mid-sleep-awakening-chart.html` (red gaps in the hatched run).

If the smoke test passes, the feature is complete.

---

## Out of scope

- **Notifications when awake mid-sleep for >30 min** — v2 candidate per spec §13.
- **Wake event categorization (toilet / dream / noise)** — v2 candidate, free-text notes for now.
- **Special chart marker** (▼ etc.) for mid-sleep awakening cells — explicit design decision in spec §6.2; the cell rule treats them as "in bed but not asleep" identical to bookend cells.
- **Statistics / trends** — separate plan.
- **HealthKit / Apple Watch auto-detection** — separate plan.

## Self-review

**Spec coverage**

| Spec section | Where in plan |
|---|---|
| §3.1 WakeEvent model with isOpen / durationMinutes | Task 1 step 1, Task 2 tests |
| §3.2 SleepSession.wakeEvents @Relationship | Task 1 step 2 |
| §3.3 invariants: in-bounds, no overlap, ordering | Task 3 (validateWakeEvents) |
| §4.1 isAwakeMidSleep predicate | Task 2 step 3 |
| §4.2 button table (再び眠る + 目覚めた) | Task 5 steps 4–5 |
| §4.3 tap flow incl. auto-close on おはよう | Task 5 steps 2–3 |
| §4.4 elapsed time formatting | Task 5 step 2 (`elapsedSinceWokeUp()`) |
| §5.1 MorningCorrectionSheet section | Task 6 |
| §5.2 DayEditSheet section | Task 7 |
| §5.3 add/delete behavior | Task 6 step 4 + Task 7 step 3 |
| §6.1 cell rule extension | Task 4 step 3 |
| §6.2 visual identical to bookend awake | (no code — natural consequence of the cell rule; verified in Task 8) |
| §6.3 notes summary `覚醒×N (M分)` | Task 4 step 4 |
| §7.1 3 new Issue cases | Task 3 step 1 |
| §7.2 validateWakeEvents | Task 3 step 2 |
| §7.3 messages | Task 3 step 3 |
| §8 13 new localization keys | Tasks 3 (3), 4 (2), 5 (5), 6 (3) = 13 |
| §9 +13 tests, 46 → 59 | Tasks 2 (5), 3 (6), 4 (3) = 14 cases |
| §10 file map | Implicit across tasks |
| §11 schema migration (no code, additive) | Task 1 (defaults) |
| §12 edge cases | Validator + cell rule guards |

Test count progression: 46 → 51 (Task 2) → 57 (Task 3) → 60 (Task 4) → 60 (Tasks 5–7).

Note: §9 budget said +13 → 59. Plan delivers +14 → 60 because Task 2 added 2 state-machine cases instead of 1 (both branches deserve coverage); +1 over budget is fine.

**Placeholder scan**

No "TBD"/"TODO"/"implement later". Every code block is complete and executable. Every catalog key referenced in code (Task 3 step 3, Task 4 step 4, Task 5 step 2) appears in the catalog (Tasks 3 step 4, 4 step 5, 5 step 1, 6 step 1).

**Type / API consistency**

- `WakeEvent` properties (`id`, `startedAt`, `endedAt`, `session`, `createdAt`, `updatedAt`, `isOpen`, `durationMinutes`) — defined in Task 1 step 1; all uses across Tasks 2–7 reference exactly these names.
- `SleepRecordValidator.Issue` cases (`wakeEventOutOfBounds`, `wakeEventOverlap`, `wakeEventInverted`) — defined Task 3 step 1; tested Task 3 step 5; consumed Task 6 step 2 + Task 7 step 1.
- `SleepStateMachine.isAwakeMidSleep(activeSession:)` — defined Task 2 step 3; consumed Task 5 step 4 + step 5.
- `closeOpenWakeEventsForMorning()` / `tapWokeUp()` / `tapBackToSleep()` / `elapsedSinceWokeUp()` — defined Task 5 step 2; consumed Task 5 steps 3–5.
- Catalog keys (`wake.summary`, `wake.summary.open`, `wake.elapsed.minutes`, etc.) — all keys used in `String(localized:)` calls match the keys added to `Localizable.xcstrings`.
