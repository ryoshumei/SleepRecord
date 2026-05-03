# Sleep Rhythm Chart iOS App — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a working iOS 17+ SwiftUI app that records nightly sleep with a 2-tap UX, displays a traditional Japanese 睡眠リズム表 chart, syncs via CloudKit, and exports PDF for medical use.

**Architecture:** Three-layer SwiftUI app — `Models` (SwiftData `@Model`), `Services` (chart projection, state machine, notifications, PDF), `Views` (TabView root with Home + Chart). All Apple-stack, zero third-party deps. xcodegen drives the Xcode project from a YAML spec.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData + CloudKit Private DB, PDFKit, UserNotifications, XCTest. xcodegen for project generation. Xcode 26.4+, iOS 17+.

**Spec reference:** `docs/superpowers/specs/2026-05-04-sleep-rhythm-chart-design.md`

**Build invocation (used in verify steps):**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj \
  -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  build
```

---

### Task 0: Generate Xcode project via xcodegen

**Files:**
- Create: `project.yml`
- Create: `SleepRecord/Info.plist`
- Create: `SleepRecord/SleepRecord.entitlements`

- [ ] **Step 1**: Write `project.yml`:

```yaml
name: SleepRecord
options:
  bundleIdPrefix: com.ryan.sleeprecord
  deploymentTarget:
    iOS: '17.0'
  developmentLanguage: ja
settings:
  base:
    SWIFT_VERSION: '5.9'
    DEVELOPMENT_TEAM: ''
    CODE_SIGN_STYLE: Automatic
    GENERATE_INFOPLIST_FILE: NO
    INFOPLIST_FILE: SleepRecord/Info.plist
    CODE_SIGN_ENTITLEMENTS: SleepRecord/SleepRecord.entitlements
    PRODUCT_BUNDLE_IDENTIFIER: com.ryan.sleeprecord
    SUPPORTS_MACCATALYST: NO
    TARGETED_DEVICE_FAMILY: '1'
targets:
  SleepRecord:
    type: application
    platform: iOS
    sources:
      - path: SleepRecord
    settings:
      base:
        ENABLE_PREVIEWS: YES
  SleepRecordTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: SleepRecordTests
    dependencies:
      - target: SleepRecord
    settings:
      base:
        BUNDLE_LOADER: $(TEST_HOST)
        TEST_HOST: $(BUILT_PRODUCTS_DIR)/SleepRecord.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/SleepRecord
schemes:
  SleepRecord:
    build:
      targets:
        SleepRecord: all
        SleepRecordTests: [test]
    test:
      targets:
        - SleepRecordTests
```

- [ ] **Step 2**: Write `SleepRecord/Info.plist` (minimal):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>ja</string>
  <key>CFBundleDisplayName</key><string>睡眠リズム</string>
  <key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$(PRODUCT_NAME)</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSRequiresIPhoneOS</key><true/>
  <key>UIApplicationSceneManifest</key>
  <dict>
    <key>UIApplicationSupportsMultipleScenes</key><false/>
  </dict>
  <key>UILaunchScreen</key><dict/>
  <key>UIRequiredDeviceCapabilities</key>
  <array><string>arm64</string></array>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
  </array>
  <key>UIBackgroundModes</key>
  <array><string>remote-notification</string></array>
</dict>
</plist>
```

- [ ] **Step 3**: Write `SleepRecord/SleepRecord.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.developer.icloud-container-identifiers</key>
  <array><string>iCloud.com.ryan.sleeprecord</string></array>
  <key>com.apple.developer.icloud-services</key>
  <array><string>CloudKit</string></array>
  <key>aps-environment</key>
  <string>development</string>
</dict>
</plist>
```

- [ ] **Step 4**: Create source dirs so xcodegen finds non-empty target paths:
```bash
mkdir -p SleepRecord/{Models,Services,Views/{Home,Chart,PDF,Settings},Utilities}
mkdir -p SleepRecordTests
touch SleepRecord/Models/.keep SleepRecordTests/.keep
```

- [ ] **Step 5**: Generate project:
```bash
cd /Users/ryan/XcodeProject/SleepRecord && xcodegen generate
```
Expected: creates `SleepRecord.xcodeproj/`.

- [ ] **Step 6**: Commit.

---

### Task 1: SleepSession model

**Files:**
- Create: `SleepRecord/Models/SleepSession.swift`

- [ ] **Step 1**: Write the model:

```swift
import Foundation
import SwiftData

@Model
final class SleepSession {
    @Attribute(.unique) var id: UUID
    var bedInAt: Date
    var bedOutAt: Date?
    var asleepAt: Date?
    var awakeAt: Date?
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bedInAt: Date,
        bedOutAt: Date? = nil,
        asleepAt: Date? = nil,
        awakeAt: Date? = nil,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.bedInAt = bedInAt
        self.bedOutAt = bedOutAt
        self.asleepAt = asleepAt
        self.awakeAt = awakeAt
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isInProgress: Bool { bedOutAt == nil }
    var isFullyRecorded: Bool { bedOutAt != nil && asleepAt != nil && awakeAt != nil }
}
```

- [ ] **Step 2**: Commit.

---

### Task 2: ChartCellCalculator (TDD)

**Files:**
- Create: `SleepRecord/Services/ChartCellCalculator.swift`
- Create: `SleepRecordTests/ChartCellCalculatorTests.swift`

The calculator projects sessions onto a 24-hour grid for any date. Cell value = `(inBed: Bool, asleep: Bool)`. Rule: any-overlap = mark cell.

- [ ] **Step 1**: Write the failing tests:

```swift
import XCTest
import Foundation
@testable import SleepRecord

final class ChartCellCalculatorTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    let tz = TimeZone(identifier: "Asia/Tokyo")!

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        c.timeZone = tz
        return cal.date(from: c)!
    }

    func testEmptyDay() {
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let cells = calc.cells(forDay: date(2026, 5, 4, 0), sessions: [])
        XCTAssertEqual(cells.count, 24)
        XCTAssertTrue(cells.allSatisfy { !$0.inBed && !$0.asleep })
    }

    func testSimpleNightSleep() {
        // 5/4 23:00 → 5/5 7:00 in bed; 5/4 23:30 → 5/5 6:30 asleep
        let s = SleepSession(
            bedInAt: date(2026, 5, 4, 23),
            bedOutAt: date(2026, 5, 5, 7),
            asleepAt: date(2026, 5, 4, 23, 30),
            awakeAt: date(2026, 5, 5, 6, 30)
        )
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)

        let day1 = calc.cells(forDay: date(2026, 5, 4, 0), sessions: [s])
        XCTAssertTrue(day1[23].inBed)
        XCTAssertTrue(day1[23].asleep)
        XCTAssertFalse(day1[22].inBed)

        let day2 = calc.cells(forDay: date(2026, 5, 5, 0), sessions: [s])
        for h in 0..<6 { XCTAssertTrue(day2[h].inBed, "hour \(h) should be in bed") }
        XCTAssertTrue(day2[6].inBed)        // 6:00-7:00 still in bed
        XCTAssertTrue(day2[6].asleep)       // overlap with 6:00-6:30 asleep
        XCTAssertFalse(day2[7].inBed)
    }

    func testInProgressSession() {
        // bedInAt only, no other fields
        let s = SleepSession(bedInAt: date(2026, 5, 4, 23, 30))
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let cells = calc.cells(forDay: date(2026, 5, 4, 0), sessions: [s])
        XCTAssertTrue(cells[23].inBed)      // 23:30 onward marked
        XCTAssertFalse(cells[23].asleep)
    }

    func testMultipleSessionsSameDay() {
        // Nap + night
        let nap = SleepSession(
            bedInAt: date(2026, 5, 4, 13),
            bedOutAt: date(2026, 5, 4, 14),
            asleepAt: date(2026, 5, 4, 13, 10),
            awakeAt: date(2026, 5, 4, 13, 50)
        )
        let night = SleepSession(
            bedInAt: date(2026, 5, 4, 23),
            bedOutAt: date(2026, 5, 5, 7),
            asleepAt: date(2026, 5, 4, 23, 30),
            awakeAt: date(2026, 5, 5, 6, 30)
        )
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let cells = calc.cells(forDay: date(2026, 5, 4, 0), sessions: [nap, night])
        XCTAssertTrue(cells[13].inBed)
        XCTAssertTrue(cells[13].asleep)
        XCTAssertTrue(cells[23].inBed)
    }

    func testPartialHourCounts() {
        // 1 second overlap = mark cell
        let s = SleepSession(
            bedInAt: date(2026, 5, 4, 23, 59),
            bedOutAt: date(2026, 5, 5, 0, 1)
        )
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let day1 = calc.cells(forDay: date(2026, 5, 4, 0), sessions: [s])
        XCTAssertTrue(day1[23].inBed)
        let day2 = calc.cells(forDay: date(2026, 5, 5, 0), sessions: [s])
        XCTAssertTrue(day2[0].inBed)
    }
}
```

- [ ] **Step 2**: Implement the calculator:

```swift
import Foundation

struct ChartCell: Equatable {
    let inBed: Bool
    let asleep: Bool
    static let empty = ChartCell(inBed: false, asleep: false)
}

struct ChartCellCalculator {
    let calendar: Calendar
    let timeZone: TimeZone

    init(calendar: Calendar = Calendar(identifier: .gregorian),
         timeZone: TimeZone = .current) {
        var cal = calendar
        cal.timeZone = timeZone
        self.calendar = cal
        self.timeZone = timeZone
    }

    /// Returns 24 cells (one per hour 0..23) for the given day in the configured timezone.
    func cells(forDay day: Date, sessions: [SleepSession]) -> [ChartCell] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return Array(repeating: .empty, count: 24)
        }

        var cells = Array(repeating: ChartCell.empty, count: 24)

        for session in sessions {
            let bedRange = session.bedInAt..<(session.bedOutAt ?? dayEnd)
            let sleepRange: Range<Date>? = {
                guard let s = session.asleepAt, let e = session.awakeAt else { return nil }
                return s..<e
            }()

            for hour in 0..<24 {
                guard let cellStart = calendar.date(byAdding: .hour, value: hour, to: dayStart),
                      let cellEnd = calendar.date(byAdding: .hour, value: hour + 1, to: dayStart)
                else { continue }
                let cellRange = cellStart..<cellEnd

                let bedOverlap = rangesOverlap(bedRange, cellRange)
                let sleepOverlap = sleepRange.map { rangesOverlap($0, cellRange) } ?? false
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

    private func rangesOverlap(_ a: Range<Date>, _ b: Range<Date>) -> Bool {
        a.lowerBound < b.upperBound && b.lowerBound < a.upperBound
    }
}
```

- [ ] **Step 3**: Run tests:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```
Expected: PASS for all `ChartCellCalculatorTests`.

- [ ] **Step 4**: Commit.

---

### Task 3: SleepStateMachine (TDD)

**Files:**
- Create: `SleepRecord/Services/SleepStateMachine.swift`
- Create: `SleepRecordTests/SleepStateMachineTests.swift`

- [ ] **Step 1**: Write tests:

```swift
import XCTest
@testable import SleepRecord

final class SleepStateMachineTests: XCTestCase {
    func testEmpty_NoSessions() {
        XCTAssertEqual(SleepStateMachine.state(activeSession: nil), .empty)
    }

    func testInBed_HasActiveSession() {
        let s = SleepSession(bedInAt: .now)
        XCTAssertEqual(SleepStateMachine.state(activeSession: s), .inBed)
    }

    func testCorrectionPending_BedOutSetButNoSleepData() {
        let s = SleepSession(bedInAt: .now, bedOutAt: .now)
        XCTAssertEqual(SleepStateMachine.state(activeSession: s), .correctionPending)
    }

    func testCompleted_AllFieldsSet() {
        let s = SleepSession(
            bedInAt: .now, bedOutAt: .now,
            asleepAt: .now, awakeAt: .now
        )
        XCTAssertEqual(SleepStateMachine.state(activeSession: s), .completed)
    }
}
```

- [ ] **Step 2**: Implement:

```swift
import Foundation

enum SleepState: Equatable {
    case empty
    case inBed
    case correctionPending
    case completed
}

enum SleepStateMachine {
    /// Active session = the most recent session (by bedInAt) for the current "sleep day window".
    /// Caller passes nil if there is no recent session in scope.
    static func state(activeSession: SleepSession?) -> SleepState {
        guard let s = activeSession else { return .empty }
        if s.bedOutAt == nil { return .inBed }
        if s.asleepAt == nil || s.awakeAt == nil { return .correctionPending }
        return .completed
    }
}
```

- [ ] **Step 3**: Run tests, expect PASS.

- [ ] **Step 4**: Commit.

---

### Task 4: BackfillDetector (TDD)

**Files:**
- Create: `SleepRecord/Services/BackfillDetector.swift`
- Create: `SleepRecordTests/BackfillDetectorTests.swift`

- [ ] **Step 1**: Tests:

```swift
import XCTest
@testable import SleepRecord

final class BackfillDetectorTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)

    func dt(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return cal.date(from: c)!
    }

    func testNoActiveSession_NeedsBackfill() {
        let now = dt(2026, 5, 4, 7)
        let result = BackfillDetector.detect(now: now, activeSession: nil, calendar: cal, timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        XCTAssertTrue(result.needsBackfill)
        // Default suggestion = previous day at 23:00
        let expected = dt(2026, 5, 3, 23)
        XCTAssertEqual(result.suggestedBedInAt, expected)
    }

    func testActiveSessionExists_NoBackfill() {
        let s = SleepSession(bedInAt: dt(2026, 5, 3, 23))
        let result = BackfillDetector.detect(now: dt(2026, 5, 4, 7), activeSession: s, calendar: cal, timeZone: .current)
        XCTAssertFalse(result.needsBackfill)
    }
}
```

- [ ] **Step 2**: Implement:

```swift
import Foundation

struct BackfillResult {
    let needsBackfill: Bool
    let suggestedBedInAt: Date?
}

enum BackfillDetector {
    static func detect(
        now: Date,
        activeSession: SleepSession?,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> BackfillResult {
        if activeSession != nil {
            return BackfillResult(needsBackfill: false, suggestedBedInAt: nil)
        }
        var cal = calendar
        cal.timeZone = timeZone
        let today = cal.startOfDay(for: now)
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
              let suggested = cal.date(byAdding: .hour, value: 23, to: yesterday)
        else {
            return BackfillResult(needsBackfill: true, suggestedBedInAt: nil)
        }
        return BackfillResult(needsBackfill: true, suggestedBedInAt: suggested)
    }
}
```

- [ ] **Step 3**: Run tests, expect PASS.

- [ ] **Step 4**: Commit.

---

### Task 5: DataStore (SwiftData container with CloudKit fallback)

**Files:**
- Create: `SleepRecord/Services/DataStore.swift`

- [ ] **Step 1**: Write the store. CloudKit may fail in development without a configured container; fall back to local-only.

```swift
import Foundation
import SwiftData

@MainActor
enum DataStore {
    static let shared: ModelContainer = {
        let schema = Schema([SleepSession.self])

        // Try CloudKit-backed; on failure (dev/no entitlement), fall back to local.
        do {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.ryan.sleeprecord")
            )
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            #if DEBUG
            print("CloudKit container failed, falling back to local-only: \(error)")
            #endif
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try! ModelContainer(for: schema, configurations: [localConfig])
        }
    }()

    static func inMemory() -> ModelContainer {
        let schema = Schema([SleepSession.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
```

- [ ] **Step 2**: Commit.

---

### Task 6: NotificationScheduler

**Files:**
- Create: `SleepRecord/Services/NotificationScheduler.swift`

- [ ] **Step 1**: Implement:

```swift
import Foundation
import UserNotifications

@MainActor
struct NotificationScheduler {
    static let bedtimeReminderID = "sleep-record.bedtime-reminder"

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    static func scheduleBedtimeReminder(at hour: Int, minute: Int) async {
        guard await requestAuthorizationIfNeeded() else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [bedtimeReminderID])

        let content = UNMutableNotificationContent()
        content.title = "そろそろお休みの時間です"
        content.body = "おやすみ前にタップを忘れずに 🌙"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: bedtimeReminderID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelBedtimeReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [bedtimeReminderID]
        )
    }

    static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
```

- [ ] **Step 2**: Commit.

---

### Task 7: PDFExporter (TDD for layout decisions)

**Files:**
- Create: `SleepRecord/Services/PDFExporter.swift`
- Create: `SleepRecordTests/PDFLayoutBuilderTests.swift`

The tests cover the page-split decision (`pages(forDays:)`), not the actual PDF rendering.

- [ ] **Step 1**: Tests:

```swift
import XCTest
@testable import SleepRecord

final class PDFLayoutBuilderTests: XCTestCase {
    func testSinglePage_30Days() {
        let pages = PDFExporter.pages(totalDays: 30)
        XCTAssertEqual(pages, 1)
    }

    func testTwoPages_36Days() {
        let pages = PDFExporter.pages(totalDays: 36)
        XCTAssertEqual(pages, 2)
    }

    func testThreePages_71Days() {
        let pages = PDFExporter.pages(totalDays: 71)
        XCTAssertEqual(pages, 3)
    }
}
```

- [ ] **Step 2**: Implement (full PDF rendering with PDFKit):

```swift
import Foundation
import PDFKit
import UIKit

@MainActor
enum PDFExporter {
    static let daysPerPage = 35
    static let cellWidth: CGFloat = 18
    static let cellHeight: CGFloat = 14
    static let labelWidth: CGFloat = 56
    static let pageMargin: CGFloat = 36
    // A4 portrait points: 595.28 x 841.89

    static func pages(totalDays: Int) -> Int {
        max(1, Int(ceil(Double(totalDays) / Double(daysPerPage))))
    }

    static func makePDF(
        sessions: [SleepSession],
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> Data {
        var cal = calendar
        cal.timeZone = timeZone

        let allDays = enumerateDays(start: startDate, end: endDate, calendar: cal)
        let calc = ChartCellCalculator(calendar: cal, timeZone: timeZone)

        let pageRect = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            let chunks = stride(from: 0, to: allDays.count, by: daysPerPage).map {
                Array(allDays[$0..<min($0 + daysPerPage, allDays.count)])
            }

            for (idx, chunk) in chunks.enumerated() {
                ctx.beginPage()
                drawHeader(rect: pageRect, startDate: startDate, endDate: endDate, pageNum: idx + 1, totalPages: chunks.count)
                drawChart(rect: pageRect, days: chunk, sessions: sessions, calc: calc, calendar: cal)
            }

            // Notes page if there are any notes
            let notes = sessions.compactMap { s -> (Date, String)? in
                guard !s.notes.isEmpty else { return nil }
                return (s.bedInAt, s.notes)
            }.sorted(by: { $0.0 < $1.0 })

            if !notes.isEmpty {
                ctx.beginPage()
                drawHeader(rect: pageRect, startDate: startDate, endDate: endDate, pageNum: chunks.count + 1, totalPages: chunks.count + 1)
                drawNotes(rect: pageRect, notes: notes, calendar: cal)
            }
        }
    }

    private static func enumerateDays(start: Date, end: Date, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var current = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while current <= endDay {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }

    private static func drawHeader(rect: CGRect, startDate: Date, endDate: Date, pageNum: Int, totalPages: Int) {
        let title = "睡眠リズム表" as NSString
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        title.draw(at: CGPoint(x: pageMargin, y: pageMargin), withAttributes: titleAttrs)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let range = "期間: \(formatter.string(from: startDate)) 〜 \(formatter.string(from: endDate))" as NSString
        let rangeAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]
        range.draw(at: CGPoint(x: pageMargin, y: pageMargin + 24), withAttributes: rangeAttrs)

        let pageStr = "\(pageNum) / \(totalPages)" as NSString
        let pageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        let size = pageStr.size(withAttributes: pageAttrs)
        pageStr.draw(at: CGPoint(x: rect.width - pageMargin - size.width, y: pageMargin + 4), withAttributes: pageAttrs)
    }

    private static func drawChart(rect: CGRect, days: [Date], sessions: [SleepSession], calc: ChartCellCalculator, calendar: Calendar) {
        let chartTop: CGFloat = pageMargin + 60
        let chartLeft = pageMargin + labelWidth

        // Hour header
        let hourFont = UIFont.systemFont(ofSize: 7)
        for h in 0..<24 {
            let str = "\(h)" as NSString
            str.draw(
                at: CGPoint(x: chartLeft + CGFloat(h) * cellWidth + 1, y: chartTop - 12),
                withAttributes: [.font: hourFont, .foregroundColor: UIColor.darkGray]
            )
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (E)"

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.black
        ]

        for (idx, day) in days.enumerated() {
            let y = chartTop + CGFloat(idx) * cellHeight
            let label = formatter.string(from: day) as NSString
            label.draw(at: CGPoint(x: pageMargin, y: y + 1), withAttributes: labelAttrs)

            let cells = calc.cells(forDay: day, sessions: sessions)
            for (h, cell) in cells.enumerated() {
                let x = chartLeft + CGFloat(h) * cellWidth
                let cellRect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                drawCell(rect: cellRect, cell: cell)
            }
        }

        // Vertical separator at hour 12
        let midX = chartLeft + 12 * cellWidth
        let separator = UIBezierPath()
        separator.move(to: CGPoint(x: midX, y: chartTop))
        separator.addLine(to: CGPoint(x: midX, y: chartTop + CGFloat(days.count) * cellHeight))
        UIColor.black.setStroke()
        separator.lineWidth = 1.5
        separator.stroke()
    }

    private static func drawCell(rect: CGRect, cell: ChartCell) {
        // Border
        UIColor.black.setStroke()
        let border = UIBezierPath(rect: rect)
        border.lineWidth = 0.3
        border.stroke()

        // Bottom half = bed (red)
        if cell.inBed {
            let bot = CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2)
            UIColor(red: 0.9, green: 0.22, blue: 0.27, alpha: 1).setFill()
            UIBezierPath(rect: bot).fill()
        }

        // Top half = sleep (black diagonal hatching)
        if cell.asleep {
            let top = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height / 2)
            UIColor.black.setFill()
            // Use a clipped pattern of diagonal lines
            UIGraphicsGetCurrentContext()?.saveGState()
            UIBezierPath(rect: top).addClip()
            let spacing: CGFloat = 2.5
            var x = top.minX - top.height
            while x < top.maxX + top.height {
                let line = UIBezierPath()
                line.move(to: CGPoint(x: x, y: top.maxY))
                line.addLine(to: CGPoint(x: x + top.height, y: top.minY))
                UIColor.black.setStroke()
                line.lineWidth = 0.6
                line.stroke()
                x += spacing
            }
            UIGraphicsGetCurrentContext()?.restoreGState()
        }
    }

    private static func drawNotes(rect: CGRect, notes: [(Date, String)], calendar: Calendar) {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (E)"

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.black
        ]
        ("備考一覧" as NSString).draw(
            at: CGPoint(x: pageMargin, y: pageMargin + 50),
            withAttributes: titleAttrs
        )

        var y: CGFloat = pageMargin + 80
        let lineAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.darkGray
        ]
        for (date, text) in notes {
            let datePrefix = "\(formatter.string(from: date))  " as NSString
            datePrefix.draw(at: CGPoint(x: pageMargin, y: y), withAttributes: dateAttrs)
            let dateWidth = datePrefix.size(withAttributes: dateAttrs).width
            let body = text as NSString
            let bodyRect = CGRect(x: pageMargin + dateWidth, y: y, width: rect.width - 2*pageMargin - dateWidth, height: 60)
            body.draw(in: bodyRect, withAttributes: lineAttrs)
            y += 32
            if y > rect.height - pageMargin { break }
        }
    }
}
```

- [ ] **Step 3**: Run tests, expect PASS.

- [ ] **Step 4**: Commit.

---

### Task 8: Utilities (DateRange, TimeFormatter)

**Files:**
- Create: `SleepRecord/Utilities/DateRange.swift`
- Create: `SleepRecord/Utilities/TimeFormatter.swift`

- [ ] **Step 1**: Write `DateRange.swift`:

```swift
import Foundation

enum DateRange {
    /// Default PDF range: 1 month back from today (inclusive).
    static func defaultPDFRange(now: Date = .now, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .month, value: -1, to: end) ?? end
        return (start, end)
    }

    /// All days from start to end (inclusive), at startOfDay.
    static func enumerate(start: Date, end: Date, calendar: Calendar = .current) -> [Date] {
        var days: [Date] = []
        var current = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while current <= endDay {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }
}
```

- [ ] **Step 2**: Write `TimeFormatter.swift`:

```swift
import Foundation

enum TimeFormatter {
    static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static let dateLabel: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d (E)"
        return f
    }()

    static let monthLabel: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f
    }()

    static func snapTo5Min(_ date: Date, calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let minute = comps.minute else { return date }
        let snapped = (minute / 5) * 5
        var newComps = comps
        newComps.minute = snapped
        newComps.second = 0
        return calendar.date(from: newComps) ?? date
    }
}
```

- [ ] **Step 3**: Commit.

---

### Task 9: HomeView

**Files:**
- Create: `SleepRecord/Views/Home/HomeView.swift`

- [ ] **Step 1**: Write the view:

```swift
import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SleepSession.bedInAt, order: .reverse) private var sessions: [SleepSession]
    @State private var showCorrectionSheet = false
    @State private var showBackfillSheet = false
    @State private var backfillSuggested: Date = .now
    @State private var now: Date = .now
    @State private var showSettings = false

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var activeSession: SleepSession? {
        sessions.first { $0.bedOutAt == nil || (!isCompleted($0)) }
    }

    var state: SleepState {
        SleepStateMachine.state(activeSession: activeSession)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: state == .inBed
                        ? [Color(red: 0.05, green: 0.05, blue: 0.17), Color(red: 0.13, green: 0.10, blue: 0.30)]
                        : [Color(red: 0.05, green: 0.05, blue: 0.17), Color(red: 0.20, green: 0.15, blue: 0.40)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer().frame(height: 16)
                    Text("SLEEP RHYTHM")
                        .font(.caption2).tracking(3).foregroundStyle(.white.opacity(0.55))
                    Text(now, format: .dateTime.year().month().day().weekday())
                        .font(.callout).foregroundStyle(.white.opacity(0.85))
                    Text(now, format: .dateTime.hour().minute())
                        .font(.system(size: 56, weight: .ultraLight))
                        .foregroundStyle(.white)

                    Spacer()

                    bigButton

                    if case .inBed = state, let s = activeSession {
                        Text("就寝中: \(s.bedInAt, format: .dateTime.hour().minute()) 〜")
                            .font(.footnote).foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape").foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCorrectionSheet) {
                if let s = activeSession {
                    MorningCorrectionSheet(session: s)
                }
            }
            .sheet(isPresented: $showBackfillSheet) {
                BackfillSheet(suggestedBedInAt: backfillSuggested) { bedInAt in
                    let s = SleepSession(bedInAt: bedInAt, bedOutAt: now)
                    modelContext.insert(s)
                    try? modelContext.save()
                    showCorrectionSheet = true
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onReceive(timer) { now = $0 }
            .onAppear { autoPresentCorrectionIfNeeded() }
        }
    }

    @ViewBuilder
    private var bigButton: some View {
        switch state {
        case .empty, .completed:
            Button(action: tapNight) {
                buttonShape(emoji: "🌙", title: "おやすみ", subtitle: "タップで入床時刻を記録",
                            colors: [Color.purple, Color(red: 0.36, green: 0.13, blue: 0.71)])
            }
        case .inBed:
            Button(action: tapMorning) {
                buttonShape(emoji: "☀️", title: "おはよう", subtitle: "タップで起床時刻を記録",
                            colors: [Color.orange, Color(red: 0.96, green: 0.62, blue: 0.04)])
            }
        case .correctionPending:
            Button(action: { showCorrectionSheet = true }) {
                buttonShape(emoji: "📝", title: "補正する", subtitle: "入眠/覚醒時刻を確定",
                            colors: [Color(red: 0.96, green: 0.62, blue: 0.04), Color.red])
            }
            .overlay(alignment: .topTrailing) {
                Circle().fill(.red).frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .offset(x: 8, y: -8)
            }
        }
    }

    private func buttonShape(emoji: String, title: String, subtitle: String, colors: [Color]) -> some View {
        VStack(spacing: 8) {
            Text(emoji).font(.system(size: 48))
            Text(title).font(.title3.bold()).foregroundStyle(.white)
        }
        .frame(width: 180, height: 180)
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(Circle())
        .shadow(color: colors.first?.opacity(0.5) ?? .clear, radius: 24, x: 0, y: 8)
        .overlay(alignment: .bottom) {
            Text(subtitle)
                .font(.caption2).foregroundStyle(.white.opacity(0.85))
                .padding(.top, 4)
                .offset(y: 28)
        }
    }

    private func tapNight() {
        let s = SleepSession(bedInAt: now)
        modelContext.insert(s)
        try? modelContext.save()
    }

    private func tapMorning() {
        guard let s = activeSession else {
            // Backfill flow
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

    private func autoPresentCorrectionIfNeeded() {
        if state == .correctionPending {
            showCorrectionSheet = true
        }
    }

    private func isCompleted(_ s: SleepSession) -> Bool {
        s.bedOutAt != nil && s.asleepAt != nil && s.awakeAt != nil
    }
}

private struct BackfillSheet: View {
    let suggestedBedInAt: Date
    let onConfirm: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var bedInAt: Date

    init(suggestedBedInAt: Date, onConfirm: @escaping (Date) -> Void) {
        self.suggestedBedInAt = suggestedBedInAt
        self.onConfirm = onConfirm
        self._bedInAt = State(initialValue: suggestedBedInAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("「おやすみ」のタップが見つかりません") {
                    Text("昨夜は何時頃に布団に入りましたか？")
                    DatePicker("入床時刻", selection: $bedInAt, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("入床時刻の補完")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("確定") { onConfirm(bedInAt); dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 2**: Commit.

---

### Task 10: MorningCorrectionSheet

**Files:**
- Create: `SleepRecord/Views/Home/MorningCorrectionSheet.swift`

- [ ] **Step 1**: Write the sheet:

```swift
import SwiftUI

struct MorningCorrectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let session: SleepSession

    @State private var asleepAt: Date
    @State private var awakeAt: Date
    @State private var notes: String

    init(session: SleepSession) {
        self.session = session
        let defaultAsleep = session.asleepAt ?? Calendar.current.date(byAdding: .minute, value: 30, to: session.bedInAt) ?? session.bedInAt
        let bedOut = session.bedOutAt ?? .now
        let defaultAwake = session.awakeAt ?? Calendar.current.date(byAdding: .minute, value: -15, to: bedOut) ?? bedOut
        self._asleepAt = State(initialValue: defaultAsleep)
        self._awakeAt = State(initialValue: defaultAwake)
        self._notes = State(initialValue: session.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("昨夜の記録").font(.headline)
                        Spacer()
                    }
                    HStack {
                        Image(systemName: "bed.double.fill").foregroundStyle(.red)
                        Text("入床: \(session.bedInAt, format: .dateTime.hour().minute())")
                        Spacer()
                        if let o = session.bedOutAt {
                            Text("起床: \(o, format: .dateTime.hour().minute())")
                        }
                    }.font(.subheadline)
                }

                Section("何時頃に眠れましたか？") {
                    DatePicker("入眠時刻", selection: $asleepAt, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }

                Section("何時頃目が覚めましたか？") {
                    DatePicker("覚醒時刻", selection: $awakeAt, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }

                Section("備考") {
                    TextField("夜中に目覚めた、寝つきが悪い、など", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("☀️ おはようございます")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("後で") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.bold()
                }
            }
        }
    }

    private func save() {
        session.asleepAt = TimeFormatter.snapTo5Min(asleepAt)
        session.awakeAt = TimeFormatter.snapTo5Min(awakeAt)
        session.notes = notes
        session.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
```

- [ ] **Step 2**: Commit.

---

### Task 11: ChartView + DayRowView

**Files:**
- Create: `SleepRecord/Views/Chart/ChartView.swift`
- Create: `SleepRecord/Views/Chart/DayRowView.swift`

- [ ] **Step 1**: Write `DayRowView.swift`:

```swift
import SwiftUI

struct DayRowView: View {
    let date: Date
    let cells: [ChartCell]

    var body: some View {
        HStack(spacing: 0) {
            Text(date, formatter: TimeFormatter.dateLabel)
                .font(.caption2)
                .frame(width: 56, alignment: .trailing)
                .padding(.trailing, 4)
            GeometryReader { geo in
                let w = geo.size.width / 24
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { h in
                            CellView(cell: cells[h], isMidday: h == 11)
                                .frame(width: w, height: 28)
                        }
                    }
                    Rectangle().fill(.black).frame(width: 1.5)
                        .offset(x: w * 12, y: 0).frame(height: 28)
                }
            }
            .frame(height: 28)
        }
    }
}

private struct CellView: View {
    let cell: ChartCell
    let isMidday: Bool

    var body: some View {
        ZStack {
            Rectangle().stroke(Color.black, lineWidth: 0.4)
            VStack(spacing: 0) {
                ZStack {
                    Rectangle().fill(.white)
                    if cell.asleep {
                        DiagonalHatch().fill(.black)
                    }
                }
                Rectangle().fill(cell.inBed ? Color(red: 0.9, green: 0.22, blue: 0.27) : .white)
            }
        }
    }
}

private struct DiagonalHatch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 3
        var x = -rect.height
        while x < rect.width + rect.height {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + 1, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + 1 + rect.height, y: rect.minY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            path.closeSubpath()
            x += spacing
        }
        return path
    }
}
```

- [ ] **Step 2**: Write `ChartView.swift`:

```swift
import SwiftUI
import SwiftData

struct ChartView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SleepSession.bedInAt, order: .reverse) private var sessions: [SleepSession]

    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDay: Date?
    @State private var showPDFExport = false

    private let calendar = Calendar.current

    var monthDays: [Date] {
        let start = displayedMonth
        guard let end = calendar.date(byAdding: .month, value: 1, to: start) else { return [] }
        return DateRange.enumerate(start: start, end: calendar.date(byAdding: .day, value: -1, to: end) ?? start)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                Divider()
                ScrollView {
                    let calc = ChartCellCalculator()
                    LazyVStack(spacing: 2) {
                        // Hour scale header
                        HStack(spacing: 0) {
                            Color.clear.frame(width: 56)
                            GeometryReader { geo in
                                let w = geo.size.width / 24
                                HStack(spacing: 0) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text("\(h)")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary)
                                            .frame(width: w, alignment: .leading)
                                    }
                                }
                            }.frame(height: 12)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 4)

                        ForEach(monthDays.reversed(), id: \.self) { day in
                            Button {
                                selectedDay = day
                            } label: {
                                DayRowView(date: day, cells: calc.cells(forDay: day, sessions: sessions))
                                    .padding(.horizontal, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("チャート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPDFExport = true } label: {
                        Image(systemName: "doc.text")
                    }
                }
            }
            .sheet(item: Binding(
                get: { selectedDay.map { DayWrapper(date: $0) } },
                set: { selectedDay = $0?.date }
            )) { wrapped in
                DayEditSheet(date: wrapped.date)
            }
            .sheet(isPresented: $showPDFExport) {
                PDFExportView()
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(displayedMonth, formatter: TimeFormatter.monthLabel).font(.headline)
            Spacer()
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = calendar.startOfMonth(for: d)
        }
    }
}

private struct DayWrapper: Identifiable {
    let date: Date
    var id: Date { date }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
```

- [ ] **Step 3**: Commit.

---

### Task 12: DayEditSheet

**Files:**
- Create: `SleepRecord/Views/Chart/DayEditSheet.swift`

- [ ] **Step 1**: Write the sheet:

```swift
import SwiftUI
import SwiftData

struct DayEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allSessions: [SleepSession]

    let date: Date

    @State private var bedInAt: Date = .now
    @State private var bedOutAt: Date = .now
    @State private var asleepAt: Date = .now
    @State private var awakeAt: Date = .now
    @State private var notes: String = ""
    @State private var existing: SleepSession?

    private var calendar: Calendar { .current }

    var body: some View {
        NavigationStack {
            Form {
                Section("時刻") {
                    DatePicker("布団に入った", selection: $bedInAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("眠った", selection: $asleepAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("目覚めた", selection: $awakeAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("布団から出た", selection: $bedOutAt, displayedComponents: [.date, .hourAndMinute])
                }
                Section("備考") {
                    TextField("メモ", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                if existing != nil {
                    Section {
                        Button("この日の記録を削除", role: .destructive) {
                            if let e = existing {
                                modelContext.delete(e)
                                try? modelContext.save()
                            }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(date, formatter: TimeFormatter.dateLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.bold() }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }

        // Find session that overlaps this day
        let match = allSessions.first { s in
            let bedRange = s.bedInAt..<(s.bedOutAt ?? dayEnd)
            return bedRange.lowerBound < dayEnd && bedRange.upperBound > dayStart
        }
        existing = match

        if let s = match {
            bedInAt = s.bedInAt
            bedOutAt = s.bedOutAt ?? s.bedInAt
            asleepAt = s.asleepAt ?? s.bedInAt
            awakeAt = s.awakeAt ?? s.bedOutAt ?? s.bedInAt
            notes = s.notes
        } else {
            bedInAt = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart) ?? dayStart
            asleepAt = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart) ?? dayStart
            awakeAt = calendar.date(bySettingHour: 6, minute: 30, second: 0, of: dayStart) ?? dayStart
            bedOutAt = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: dayStart) ?? dayStart
            notes = ""
        }
    }

    private func save() {
        if let s = existing {
            s.bedInAt = bedInAt
            s.bedOutAt = bedOutAt
            s.asleepAt = asleepAt
            s.awakeAt = awakeAt
            s.notes = notes
            s.updatedAt = .now
        } else {
            let s = SleepSession(
                bedInAt: bedInAt, bedOutAt: bedOutAt,
                asleepAt: asleepAt, awakeAt: awakeAt, notes: notes
            )
            modelContext.insert(s)
        }
        try? modelContext.save()
        dismiss()
    }
}
```

- [ ] **Step 2**: Commit.

---

### Task 13: SettingsView

**Files:**
- Create: `SleepRecord/Views/Settings/SettingsView.swift`

- [ ] **Step 1**: Write the view:

```swift
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("bedtimeReminderEnabled") private var reminderEnabled = true
    @AppStorage("bedtimeReminderHour") private var reminderHour = 22
    @AppStorage("bedtimeReminderMinute") private var reminderMinute = 30

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var iCloudAvailable: Bool = FileManager.default.ubiquityIdentityToken != nil

    var body: some View {
        NavigationStack {
            Form {
                Section("就寝時刻リマインダー") {
                    Toggle("通知を有効にする", isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) { _, new in
                            Task { await applyReminder(enabled: new) }
                        }
                    if reminderEnabled {
                        DatePicker(
                            "通知時刻",
                            selection: Binding(
                                get: { dateForHM(reminderHour, reminderMinute) },
                                set: { d in
                                    let comps = Calendar.current.dateComponents([.hour, .minute], from: d)
                                    reminderHour = comps.hour ?? 22
                                    reminderMinute = comps.minute ?? 30
                                    Task { await applyReminder(enabled: true) }
                                }
                            ),
                            displayedComponents: [.hourAndMinute]
                        )
                    }
                    HStack {
                        Text("通知許可状態")
                        Spacer()
                        Text(notificationStatus.label).foregroundStyle(.secondary)
                    }
                }

                Section("iCloud 同期") {
                    HStack {
                        Image(systemName: iCloudAvailable ? "checkmark.icloud.fill" : "xmark.icloud.fill")
                            .foregroundStyle(iCloudAvailable ? .green : .secondary)
                        Text(iCloudAvailable ? "iCloud で同期中" : "iCloud アカウント未設定")
                    }
                    if !iCloudAvailable {
                        Text("「設定 > Apple ID > iCloud」でアカウントを有効にすると、データが iCloud に同期されます。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("このアプリについて") {
                    HStack { Text("バージョン"); Spacer(); Text("1.0.0").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } }
            }
            .task {
                notificationStatus = await NotificationScheduler.currentAuthorizationStatus()
            }
        }
    }

    private func dateForHM(_ h: Int, _ m: Int) -> Date {
        var comps = DateComponents(); comps.hour = h; comps.minute = m
        return Calendar.current.date(from: comps) ?? .now
    }

    private func applyReminder(enabled: Bool) async {
        if enabled {
            await NotificationScheduler.scheduleBedtimeReminder(at: reminderHour, minute: reminderMinute)
        } else {
            NotificationScheduler.cancelBedtimeReminder()
        }
        notificationStatus = await NotificationScheduler.currentAuthorizationStatus()
    }
}

private extension UNAuthorizationStatus {
    var label: String {
        switch self {
        case .authorized: return "許可済み"
        case .denied: return "拒否"
        case .notDetermined: return "未確認"
        case .provisional: return "暫定"
        case .ephemeral: return "一時"
        @unknown default: return "不明"
        }
    }
}
```

- [ ] **Step 2**: Commit.

---

### Task 14: PDFExportView + PDFPreviewView

**Files:**
- Create: `SleepRecord/Views/PDF/PDFExportView.swift`
- Create: `SleepRecord/Views/PDF/PDFPreviewView.swift`

- [ ] **Step 1**: Write `PDFPreviewView.swift`:

```swift
import SwiftUI
import PDFKit

struct PDFPreviewView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.document = PDFDocument(data: data)
        return v
    }
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
    }
}
```

- [ ] **Step 2**: Write `PDFExportView.swift`:

```swift
import SwiftUI
import SwiftData

struct PDFExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SleepSession.bedInAt) private var sessions: [SleepSession]

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var pdfData: Data?
    @State private var isGenerating = false

    init() {
        let r = DateRange.defaultPDFRange()
        self._startDate = State(initialValue: r.start)
        self._endDate = State(initialValue: r.end)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("出力期間") {
                        DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                        DatePicker("終了日", selection: $endDate, in: startDate..., displayedComponents: .date)
                        Button("この期間でプレビュー") { generate() }
                    }
                }
                .frame(maxHeight: 240)

                if let data = pdfData {
                    PDFPreviewView(data: data)
                        .background(Color(.systemGroupedBackground))
                    HStack(spacing: 12) {
                        ShareLink(item: pdfFile(data: data)) {
                            Label("共有 / 保存", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Button(action: { presentPrint(data: data) }) {
                            Label("印刷", systemImage: "printer")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding()
                } else {
                    Spacer()
                    if isGenerating {
                        ProgressView("生成中…")
                    } else {
                        Text("「プレビュー」を押して PDF を生成してください")
                            .foregroundStyle(.secondary).padding()
                    }
                    Spacer()
                }
            }
            .navigationTitle("PDF出力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
            }
            .task { generate() }
        }
    }

    @MainActor
    private func generate() {
        isGenerating = true
        let data = PDFExporter.makePDF(
            sessions: Array(sessions),
            startDate: startDate,
            endDate: endDate
        )
        pdfData = data
        isGenerating = false
    }

    private func pdfFile(data: Data) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sleep-rhythm-\(Int(Date().timeIntervalSince1970)).pdf")
        try? data.write(to: url)
        return url
    }

    private func presentPrint(data: Data) {
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = "睡眠リズム表"
        let pc = UIPrintInteractionController.shared
        pc.printInfo = info
        pc.printingItem = data
        pc.present(animated: true) { _, _, _ in }
    }
}
```

- [ ] **Step 3**: Commit.

---

### Task 15: SleepRecordApp.swift root

**Files:**
- Create: `SleepRecord/SleepRecordApp.swift`

- [ ] **Step 1**: Write the entry point:

```swift
import SwiftUI
import SwiftData

@main
struct SleepRecordApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(DataStore.shared)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "moon.zzz.fill") }
            ChartView()
                .tabItem { Label("チャート", systemImage: "chart.bar.doc.horizontal") }
        }
        .tint(.purple)
    }
}
```

- [ ] **Step 2**: Commit.

---

### Task 16: Build & test verification

- [ ] **Step 1**: Re-run xcodegen to pick up all new files:
```bash
cd /Users/ryan/XcodeProject/SleepRecord && xcodegen generate
```

- [ ] **Step 2**: Build:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -40
```
Expected: `BUILD SUCCEEDED`. Fix any compile errors found.

- [ ] **Step 3**: Run tests:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tail -60
```
Expected: All tests PASS.

- [ ] **Step 4**: Final commit summarizing the build verification.

---

## Self-Review Notes

- Spec coverage: All sections of `2026-05-04-sleep-rhythm-chart-design.md` have a corresponding task.
- CloudKit container in `DataStore` falls back to local-only on failure so the project builds even without a configured developer team.
- Code signing is disabled (`CODE_SIGNING_ALLOWED=NO`) for build verification since no team is configured.
- PDF page-split logic is testable; PDF rendering itself is visual and verified by manual run in simulator.
- View state ownership: `HomeView` derives state from `@Query` of `SleepSession`. The "active session" is `sessions.first` (most recent); refined logic could check date window if needed in v2.
