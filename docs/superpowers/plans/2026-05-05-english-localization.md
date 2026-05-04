# SleepRecord English Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add English UI alongside Japanese using iOS 17+ String Catalog, with an in-app language picker (System / 日本語 / English) that takes effect on next launch.

**Architecture:** Two `*.xcstrings` catalogs (`Localizable.xcstrings` for UI, `InfoPlist.xcstrings` for the bundle display name) hold both languages. SwiftUI `Text("…")` calls auto-look-up via `LocalizedStringKey` — no call-site changes. Service-layer code (`SleepRecordValidator`, `NotificationScheduler`, `PDFExporter`) switches to `String(localized: "key", defaultValue: "Japanese fallback")`. A new `LanguagePreference` service writes the user's choice to the iOS-recognized `AppleLanguages` UserDefaults key; restart applies it.

**Tech Stack:** SwiftUI, Foundation `String(localized:)`, String Catalog (`*.xcstrings`), `UserDefaults` for `AppleLanguages` override, XCTest.

**Spec reference:** `docs/superpowers/specs/2026-05-05-english-localization-design.md`

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
| `SleepRecord/Localizable.xcstrings` | Create. JSON catalog of ~55 ja/en string pairs. |
| `SleepRecord/InfoPlist.xcstrings` | Create. One key (`CFBundleDisplayName`) with ja/en. |
| `SleepRecord/Info.plist` | Modify. Add `CFBundleLocalizations`; remove hardcoded `CFBundleDisplayName`. |
| `SleepRecord/Services/LanguagePreference.swift` | Create. ~35 lines. Holds user's language choice; writes `AppleLanguages` UserDefaults. |
| `SleepRecord/Services/SleepRecordValidator.swift` | Modify (lines 50–67). Replace JP literal returns with `String(localized: ..., defaultValue: ...)`. |
| `SleepRecord/Services/NotificationScheduler.swift` | Modify (lines 29–30). Replace JP literal title/body. |
| `SleepRecord/Services/PDFExporter.swift` | Modify. Replace `Locale(identifier: "ja_JP")` with `.current`; replace JP labels with `String(localized:)`. |
| `SleepRecord/Views/Settings/SettingsView.swift` | Modify. Add language Picker section + restart alert. |
| `SleepRecord/Views/PDF/PDFExportView.swift` | Modify (line 93 `info.jobName = "睡眠リズム表"`). Replace with `String(localized:)`. |
| `SleepRecordTests/SleepRecordValidatorTests.swift` | Modify (lines 153–167). Make 3 message tests locale-stable. |
| `SleepRecordTests/LanguagePreferenceTests.swift` | Create. 3 cases. |
| `SleepRecordTests/LocalizationCoverageTests.swift` | Create. 4 cases — assert en translations exist for validator keys. |

`project.yml` — no change. xcodegen picks up `*.xcstrings` automatically.

---

## Task 1: Foundation — empty xcstrings, Info.plist, project regen, build green

**Goal:** Build still passes with the new asset infra in place but **no English translations yet** (development language `ja` still wins everywhere). Establishes a green baseline before semantic changes.

**Files:**
- Create: `SleepRecord/Localizable.xcstrings`
- Create: `SleepRecord/InfoPlist.xcstrings`
- Modify: `SleepRecord/Info.plist`

- [ ] **Step 1: Write `SleepRecord/Localizable.xcstrings`**

```json
{
  "sourceLanguage" : "ja",
  "strings" : {},
  "version" : "1.0"
}
```

(An empty strings dictionary. Xcode's build phase will auto-populate it with keys it discovers in source code on first build, but we'll also pre-fill it explicitly in Task 5 to avoid relying on the extraction step.)

- [ ] **Step 2: Write `SleepRecord/InfoPlist.xcstrings`**

```json
{
  "sourceLanguage" : "ja",
  "strings" : {
    "CFBundleDisplayName" : {
      "extractionState" : "manual",
      "localizations" : {
        "ja" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "睡眠リズム"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Sleep Rhythm"
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```

- [ ] **Step 3: Update `SleepRecord/Info.plist`** — add `CFBundleLocalizations`, remove hardcoded `CFBundleDisplayName`

Replace the line `<key>CFBundleDisplayName</key><string>睡眠リズム</string>` with:

```xml
  <key>CFBundleLocalizations</key>
  <array>
    <string>ja</string>
    <string>en</string>
  </array>
```

`CFBundleDisplayName` is removed because it now lives in `InfoPlist.xcstrings` (Apple's standard localization mechanism overrides the static value).

- [ ] **Step 4: Regenerate Xcode project**

Run: `xcodegen generate`
Expected: `Created project at SleepRecord.xcodeproj`. The new `.xcstrings` files appear in the SleepRecord target's Resources build phase.

- [ ] **Step 5: Build for Simulator**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`. The catalogs compile into `*.lproj/Localizable.strings` inside `SleepRecord.app`.

- [ ] **Step 6: Verify the catalog compiled**

Run:

```bash
ls "/Users/ryan/Library/Developer/Xcode/DerivedData/SleepRecord-ddmwrmmbtucbvydtevhibasogwyw/Build/Products/Debug-iphonesimulator/SleepRecord.app/" | grep lproj
```

Expected: at least `ja.lproj` (development language always emitted) and `en.lproj` once we add EN translations in Task 5. After only this task, expect `ja.lproj` and possibly `en.lproj` (empty).

- [ ] **Step 7: Run tests (regression)**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Expected: `Executed 39 tests, with 0 failures` and `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add SleepRecord/Localizable.xcstrings \
        SleepRecord/InfoPlist.xcstrings \
        SleepRecord/Info.plist \
        SleepRecord.xcodeproj/project.pbxproj \
        docs/superpowers/specs/2026-05-05-english-localization-design.md \
        docs/superpowers/plans/2026-05-05-english-localization.md
git commit -m "$(cat <<'EOF'
i18n: scaffold String Catalogs and Info.plist for ja/en

Empty Localizable.xcstrings + InfoPlist.xcstrings (with CFBundleDisplayName
ja=睡眠リズム / en=Sleep Rhythm). Info.plist now declares both localizations
and delegates the display name to the catalog. Build green; 39/39 tests
unchanged. Translations are filled in a later task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Service-layer `String(localized:)` refactor + validator test fix

**Goal:** Convert non-SwiftUI strings (validator messages, notification body, PDF labels, PDF print job name) to use `String(localized: "key", defaultValue: "Japanese")`. After this task, behavior on a JP device is identical (defaultValue still wins because no en translation registered yet).

**Files:**
- Modify: `SleepRecord/Services/SleepRecordValidator.swift`
- Modify: `SleepRecord/Services/NotificationScheduler.swift`
- Modify: `SleepRecord/Services/PDFExporter.swift`
- Modify: `SleepRecord/Views/PDF/PDFExportView.swift`
- Modify: `SleepRecordTests/SleepRecordValidatorTests.swift`

- [ ] **Step 1: Update `SleepRecordValidator.swift` message extension**

Replace lines 48–68 (the `extension SleepRecordValidator.Issue { func message(...) }` block) with:

```swift
extension SleepRecordValidator.Issue {
    /// Display message for the given issue, used in form error labels.
    /// Looks up the localized string at runtime; defaultValue is the Japanese
    /// development-language source.
    func message(bedInAt: Date? = nil, bedOutAt: Date? = nil) -> String {
        switch self {
        case .bedWindowInverted:
            return String(
                localized: "validator.bedWindowInverted",
                defaultValue: "「布団に入った」は「布団から出た」より前である必要があります"
            )
        case .asleepBeforeBedIn:
            if let d = bedInAt {
                let time = SleepRecordValidator.shortTime(d)
                return String(
                    localized: "validator.asleepBeforeBedIn.withTime \(time)",
                    defaultValue: "入眠時刻は入床時刻(\(time))以降にしてください"
                )
            }
            return String(
                localized: "validator.asleepBeforeBedIn",
                defaultValue: "「眠った」は「布団に入った」以降である必要があります"
            )
        case .awakeAfterBedOut:
            if let d = bedOutAt {
                let time = SleepRecordValidator.shortTime(d)
                return String(
                    localized: "validator.awakeAfterBedOut.withTime \(time)",
                    defaultValue: "覚醒時刻は起床時刻(\(time))以前にしてください"
                )
            }
            return String(
                localized: "validator.awakeAfterBedOut",
                defaultValue: "「目覚めた」は「布団から出た」以前である必要があります"
            )
        case .asleepAfterAwake:
            return String(
                localized: "validator.asleepAfterAwake",
                defaultValue: "「眠った」は「目覚めた」より前である必要があります"
            )
        }
    }
}
```

The `\(time)` interpolation inside the localization key uses Swift's `LocalizationValue` — `String(localized:)` understands the placeholder and the catalog stores it as `"...入床時刻(%@)以降..."`.

- [ ] **Step 2: Update `NotificationScheduler.swift`**

Replace lines 29–30 (the two literal strings) with:

```swift
        content.title = String(
            localized: "notification.bedtimeReminder.title",
            defaultValue: "そろそろお休みの時間です"
        )
        content.body = String(
            localized: "notification.bedtimeReminder.body",
            defaultValue: "おやすみ前にタップを忘れずに 🌙"
        )
```

- [ ] **Step 3: Update `PDFExporter.swift`** — replace four hardcoded strings + the locale identifier

a) `PDFExporter.swift:72` (drawHeader title):

```swift
        let title = String(
            localized: "pdf.title",
            defaultValue: "睡眠リズム表"
        ) as NSString
```

b) `PDFExporter.swift:81` (drawHeader period prefix):

```swift
        let rangeFormatted = String(
            localized: "pdf.period \(formatter.string(from: startDate)) \(formatter.string(from: endDate))",
            defaultValue: "期間: \(formatter.string(from: startDate)) 〜 \(formatter.string(from: endDate))"
        )
        let range = rangeFormatted as NSString
```

c) `PDFExporter.swift:133–135` (drawChart banner labels — change the three literal strings):

```swift
        let amLabel = String(localized: "chart.am", defaultValue: "午前") as NSString
        let pmLabel = String(localized: "chart.pm", defaultValue: "午後") as NSString
        let notesLabel = String(localized: "chart.notes", defaultValue: "備考欄") as NSString
        amLabel.draw(in: amRect.insetBy(dx: 0, dy: 1), withAttributes: bannerAttrs)
        pmLabel.draw(in: pmRect.insetBy(dx: 0, dy: 1), withAttributes: bannerAttrs)
        notesLabel.draw(in: notesBannerRect.insetBy(dx: 0, dy: 1), withAttributes: bannerAttrs)
```

d) `PDFExporter.swift:157` (formatter locale):

Replace `formatter.locale = Locale(identifier: "ja_JP")` with:

```swift
        formatter.locale = .current
```

This makes per-row date labels render `5/4 (Mon)` on EN devices and `5/4 (月)` on JP devices.

- [ ] **Step 4: Update `PDFExportView.swift`** — print job name

Replace line 93 (`info.jobName = "睡眠リズム表"`) with:

```swift
        info.jobName = String(localized: "pdf.title", defaultValue: "睡眠リズム表")
```

(Reuses the same `pdf.title` key as the in-PDF header.)

- [ ] **Step 5: Update validator message tests for locale stability**

Replace lines 151–167 of `SleepRecordValidatorTests.swift` (the three "MARK: messages" tests) with:

```swift
    // MARK: messages

    func testMessage_BedWindowInverted_NonEmpty() {
        let m = SleepRecordValidator.Issue.bedWindowInverted.message()
        XCTAssertFalse(m.isEmpty)
    }

    func testMessage_AsleepBeforeBedIn_IncludesTimeWhenProvided() {
        let bedIn = dt(2026, 5, 4, 23, 0)
        let m = SleepRecordValidator.Issue.asleepBeforeBedIn.message(bedInAt: bedIn)
        let timeStr = SleepRecordValidator.shortTime(bedIn)
        XCTAssertTrue(
            m.contains(timeStr),
            "message should include the bedInAt time '\(timeStr)' but was '\(m)'"
        )
    }

    func testMessage_AsleepAfterAwake_NonEmpty() {
        let m = SleepRecordValidator.Issue.asleepAfterAwake.message()
        XCTAssertFalse(m.isEmpty)
    }
```

Why: the previous tests asserted Japanese substrings ("布団", "入床", "眠"). After localization, the runtime locale of the test process determines whether the message comes back in JP or EN. Asserting "non-empty" + "includes the time interpolation" is locale-stable while still verifying the same correctness intent (message exists, time is woven in).

- [ ] **Step 6: Build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Run tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Expected: `Executed 39 tests, with 0 failures`. (Test count unchanged — we replaced 3 tests with 3 new tests in the same suite.)

- [ ] **Step 8: Commit**

```bash
git add SleepRecord/Services/SleepRecordValidator.swift \
        SleepRecord/Services/NotificationScheduler.swift \
        SleepRecord/Services/PDFExporter.swift \
        SleepRecord/Views/PDF/PDFExportView.swift \
        SleepRecordTests/SleepRecordValidatorTests.swift
git commit -m "$(cat <<'EOF'
i18n: route service-layer strings through String(localized:)

Validator messages, notification body/title, PDF header/labels/job
name, and the per-row PDF date locale all switch to the modern
String(localized: defaultValue:) form so the catalog can override at
runtime. Behavior on a JP device is identical because the defaultValue
matches the previous literal. Validator tests rewritten to be
locale-stable (assert non-empty + time interpolation).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `LanguagePreference` service + tests

**Goal:** Pure logic for "user picked System / 日本語 / English" — write to `AppleLanguages` UserDefaults, read on next launch. Three unit tests prove the read/write behavior.

**Files:**
- Create: `SleepRecord/Services/LanguagePreference.swift`
- Create: `SleepRecordTests/LanguagePreferenceTests.swift`

- [ ] **Step 1: Write the test file FIRST (TDD)**

Path: `SleepRecordTests/LanguagePreferenceTests.swift`

```swift
import XCTest
@testable import SleepRecord

final class LanguagePreferenceTests: XCTestCase {
    let defaults = UserDefaults.standard

    override func tearDown() {
        defaults.removeObject(forKey: LanguagePreference.userPrefKey)
        defaults.removeObject(forKey: LanguagePreference.appleLanguagesKey)
        super.tearDown()
    }

    func testApplyEnglish_WritesAppleLanguages() {
        let pref = LanguagePreference.makeForTesting()
        pref.selected = .english
        XCTAssertEqual(defaults.array(forKey: LanguagePreference.appleLanguagesKey) as? [String], ["en"])
        XCTAssertEqual(defaults.string(forKey: LanguagePreference.userPrefKey), "en")
    }

    func testApplyJapanese_WritesAppleLanguages() {
        let pref = LanguagePreference.makeForTesting()
        pref.selected = .japanese
        XCTAssertEqual(defaults.array(forKey: LanguagePreference.appleLanguagesKey) as? [String], ["ja"])
        XCTAssertEqual(defaults.string(forKey: LanguagePreference.userPrefKey), "ja")
    }

    func testApplySystem_RemovesAppleLanguagesOverride() {
        defaults.set(["en"], forKey: LanguagePreference.appleLanguagesKey)
        let pref = LanguagePreference.makeForTesting()
        pref.selected = .system
        XCTAssertNil(defaults.array(forKey: LanguagePreference.appleLanguagesKey))
        XCTAssertEqual(defaults.string(forKey: LanguagePreference.userPrefKey), "")
    }
}
```

- [ ] **Step 2: Verify the tests fail (no `LanguagePreference` type yet)**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tail -10
```

Expected: build error — `Cannot find 'LanguagePreference' in scope`.

- [ ] **Step 3: Write `SleepRecord/Services/LanguagePreference.swift`**

```swift
import Foundation
import SwiftUI

enum LanguageOption: String, CaseIterable, Identifiable, Hashable {
    case system = ""
    case japanese = "ja"
    case english = "en"
    var id: String { rawValue }
}

/// User's language preference. Backed by `UserDefaults.standard`.
/// `selected` is observable so SwiftUI Pickers bind to it directly.
@Observable
final class LanguagePreference {
    static let appleLanguagesKey = "AppleLanguages"
    static let userPrefKey = "appLanguage"

    static let shared = LanguagePreference()

    /// Test-only factory that bypasses the singleton so each test starts fresh.
    static func makeForTesting() -> LanguagePreference {
        LanguagePreference()
    }

    var selected: LanguageOption {
        didSet { apply() }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.userPrefKey) ?? ""
        self.selected = LanguageOption(rawValue: raw) ?? .system
    }

    private func apply() {
        let defaults = UserDefaults.standard
        defaults.set(selected.rawValue, forKey: Self.userPrefKey)
        switch selected {
        case .system:
            defaults.removeObject(forKey: Self.appleLanguagesKey)
        case .japanese, .english:
            defaults.set([selected.rawValue], forKey: Self.appleLanguagesKey)
        }
    }
}
```

- [ ] **Step 4: Regenerate project (new source file)**

Run: `xcodegen generate`
Expected: `Created project at SleepRecord.xcodeproj`.

- [ ] **Step 5: Run tests — expect 42 pass**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Expected: `Executed 42 tests, with 0 failures`. (39 + 3 new = 42.)

- [ ] **Step 6: Commit**

```bash
git add SleepRecord/Services/LanguagePreference.swift \
        SleepRecordTests/LanguagePreferenceTests.swift \
        SleepRecord.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
i18n: add LanguagePreference service (UserDefaults-backed)

@Observable wrapper for the user's language choice (System / 日本語 /
English). Writes the standard AppleLanguages key in UserDefaults so iOS
honors the override on next app launch. 3 tests cover write+remove paths.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Language Picker section in `SettingsView`

**Goal:** Add a Settings UI surface that drives `LanguagePreference.shared.selected` and shows a restart alert.

**Files:**
- Modify: `SleepRecord/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Read the current file to confirm line numbers**

Run: `Read SleepRecord/Views/Settings/SettingsView.swift`
Expected: `Section("このアプリについて")` is at line 55–57; `.navigationTitle("設定")` is at line 59.

- [ ] **Step 2: Add `@State` for the alert and a `@Bindable` reference to the singleton**

Inside the `SettingsView` struct, after line 11 (`@State private var iCloudAvailable: Bool = ...`), insert:

```swift
    @State private var languagePref = LanguagePreference.shared
    @State private var showLanguageRestartAlert = false
```

Note: `LanguagePreference` is `@Observable`, so `@State` (or `@Bindable` in inner views) suffices for SwiftUI to track changes.

- [ ] **Step 3: Insert the language Section** between the existing iCloud section and the "このアプリについて" section

Find the line `Section("このアプリについて") {` and insert ABOVE it:

```swift
                Section("言語 / Language") {
                    Picker("言語 / Language", selection: $languagePref.selected) {
                        Text("System (システム)").tag(LanguageOption.system)
                        Text("日本語").tag(LanguageOption.japanese)
                        Text("English").tag(LanguageOption.english)
                    }
                    .onChange(of: languagePref.selected) { _, _ in
                        showLanguageRestartAlert = true
                    }
                }

```

- [ ] **Step 4: Attach the alert modifier** to the `Form` (or to the `NavigationStack`).

Find the line `.navigationTitle("設定")` (now ~line 60). Right before it, on the same `Form`, add:

```swift
            .alert(
                "再起動が必要 / Restart Required",
                isPresented: $showLanguageRestartAlert
            ) {
                Button("OK") { }
            } message: {
                Text("言語を変更するにはアプリを再起動してください\nRestart the app to apply the language change")
            }
```

The end result should look like:

```swift
            }
            .alert(
                "再起動が必要 / Restart Required",
                isPresented: $showLanguageRestartAlert
            ) {
                Button("OK") { }
            } message: {
                Text("言語を変更するにはアプリを再起動してください\nRestart the app to apply the language change")
            }
            .navigationTitle("設定")
            .toolbar {
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

Expected: `Executed 42 tests, with 0 failures`.

- [ ] **Step 7: Commit**

```bash
git add SleepRecord/Views/Settings/SettingsView.swift
git commit -m "$(cat <<'EOF'
i18n: add language Picker to Settings (System / 日本語 / English)

New section in SettingsView wired to LanguagePreference.shared. Picker
change shows a bilingual restart alert; user must relaunch the app for
the new language to take effect (iOS standard behavior).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Fill English translations in `Localizable.xcstrings`

**Goal:** Replace the empty strings dict from Task 1 with the full ja/en mapping for every user-facing string in the app.

**Files:**
- Modify: `SleepRecord/Localizable.xcstrings` (overwrite contents)

- [ ] **Step 1: Overwrite `SleepRecord/Localizable.xcstrings` with the full catalog**

Path: `SleepRecord/Localizable.xcstrings`

```json
{
  "sourceLanguage" : "ja",
  "version" : "1.0",
  "strings" : {
    "ホーム" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "ホーム" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Home" } }
    } },
    "チャート" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "チャート" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Chart" } }
    } },
    "設定" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "設定" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Settings" } }
    } },
    "完了" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "完了" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Done" } }
    } },
    "キャンセル" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "キャンセル" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Cancel" } }
    } },
    "保存" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "保存" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Save" } }
    } },
    "後で" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "後で" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Later" } }
    } },
    "確定" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "確定" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Confirm" } }
    } },
    "閉じる" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "閉じる" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Close" } }
    } },

    "おやすみ" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "おやすみ" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Good night" } }
    } },
    "おはよう" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "おはよう" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Good morning" } }
    } },
    "補正する" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "補正する" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Adjust" } }
    } },
    "タップで入床時刻を記録" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "タップで入床時刻を記録" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Tap to record bedtime" } }
    } },
    "タップで起床時刻を記録" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "タップで起床時刻を記録" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Tap to record wake-up time" } }
    } },
    "入眠/覚醒時刻を確定" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "入眠/覚醒時刻を確定" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Confirm asleep/wake times" } }
    } },
    "「おやすみ」のタップが見つかりません" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "「おやすみ」のタップが見つかりません" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "No \"Good night\" tap found" } }
    } },
    "昨夜は何時頃に布団に入りましたか？" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "昨夜は何時頃に布団に入りましたか？" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "About what time did you go to bed last night?" } }
    } },
    "入床時刻" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "入床時刻" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Bedtime" } }
    } },
    "入床時刻の補完" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "入床時刻の補完" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Set Bedtime" } }
    } },

    "☀️ おはようございます" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "☀️ おはようございます" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "☀️ Good Morning" } }
    } },
    "昨夜の記録（編集可能）" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "昨夜の記録（編集可能）" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Last night's record (editable)" } }
    } },
    "入床" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "入床" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Bedtime" } }
    } },
    "起床" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "起床" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Wake-up" } }
    } },
    "何時頃に眠れましたか？" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "何時頃に眠れましたか？" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "About what time did you fall asleep?" } }
    } },
    "何時頃目が覚めましたか？" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "何時頃目が覚めましたか？" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "About what time did you wake up?" } }
    } },
    "入眠時刻" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "入眠時刻" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Asleep time" } }
    } },
    "覚醒時刻" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "覚醒時刻" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Wake time" } }
    } },
    "備考" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "備考" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Notes" } }
    } },
    "夜中に目覚めた、寝つきが悪い、など" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "夜中に目覚めた、寝つきが悪い、など" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Woke up at night, trouble falling asleep, etc." } }
    } },

    "時刻" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "時刻" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Times" } }
    } },
    "布団に入った" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "布団に入った" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Got in bed" } }
    } },
    "眠った" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "眠った" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Fell asleep" } }
    } },
    "目覚めた" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "目覚めた" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Woke up" } }
    } },
    "布団から出た" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "布団から出た" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Got out of bed" } }
    } },
    "メモ" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "メモ" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Note" } }
    } },
    "この日の記録を削除" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "この日の記録を削除" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Delete this day's record" } }
    } },

    "午前" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "午前" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "AM" } }
    } },
    "午後" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "午後" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "PM" } }
    } },
    "備考欄" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "備考欄" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Notes" } }
    } },

    "就寝時刻リマインダー" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "就寝時刻リマインダー" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Bedtime reminder" } }
    } },
    "通知を有効にする" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "通知を有効にする" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Enable notifications" } }
    } },
    "通知時刻" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "通知時刻" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Notification time" } }
    } },
    "通知許可状態" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "通知許可状態" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Notification permission" } }
    } },
    "iCloud 同期" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "iCloud 同期" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "iCloud Sync" } }
    } },
    "iCloud で同期中" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "iCloud で同期中" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Syncing with iCloud" } }
    } },
    "iCloud アカウント未設定" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "iCloud アカウント未設定" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "iCloud account not configured" } }
    } },
    "「設定 > Apple ID > iCloud」でアカウントを有効にすると、データが iCloud に同期されます。" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "「設定 > Apple ID > iCloud」でアカウントを有効にすると、データが iCloud に同期されます。" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Enable an account in Settings > Apple ID > iCloud to sync data with iCloud." } }
    } },
    "このアプリについて" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "このアプリについて" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "About" } }
    } },
    "バージョン" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "バージョン" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Version" } }
    } },

    "言語 / Language" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "言語 / Language" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "言語 / Language" } }
    } },
    "System (システム)" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "System (システム)" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "System (システム)" } }
    } },
    "再起動が必要 / Restart Required" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "再起動が必要 / Restart Required" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "再起動が必要 / Restart Required" } }
    } },
    "言語を変更するにはアプリを再起動してください\nRestart the app to apply the language change" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "言語を変更するにはアプリを再起動してください\nRestart the app to apply the language change" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "言語を変更するにはアプリを再起動してください\nRestart the app to apply the language change" } }
    } },

    "出力期間" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "出力期間" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Date range" } }
    } },
    "開始日" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "開始日" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Start date" } }
    } },
    "終了日" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "終了日" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "End date" } }
    } },
    "この期間でプレビュー" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "この期間でプレビュー" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Preview" } }
    } },
    "共有 / 保存" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "共有 / 保存" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Share / Save" } }
    } },
    "印刷" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "印刷" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Print" } }
    } },
    "生成中…" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "生成中…" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Generating…" } }
    } },
    "「プレビュー」を押して PDF を生成してください" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "「プレビュー」を押して PDF を生成してください" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Tap Preview to generate the PDF" } }
    } },
    "PDF出力" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "PDF出力" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Export PDF" } }
    } },

    "validator.bedWindowInverted" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "「布団に入った」は「布団から出た」より前である必要があります" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "\"Got in bed\" must be earlier than \"Got out of bed\"" } }
    } },
    "validator.asleepBeforeBedIn" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "「眠った」は「布団に入った」以降である必要があります" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "\"Fell asleep\" must be at or after \"Got in bed\"" } }
    } },
    "validator.asleepBeforeBedIn.withTime %@" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "入眠時刻は入床時刻(%@)以降にしてください" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Asleep time must be at or after bedtime (%@)" } }
    } },
    "validator.awakeAfterBedOut" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "「目覚めた」は「布団から出た」以前である必要があります" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "\"Woke up\" must be at or before \"Got out of bed\"" } }
    } },
    "validator.awakeAfterBedOut.withTime %@" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "覚醒時刻は起床時刻(%@)以前にしてください" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Wake time must be at or before wake-up (%@)" } }
    } },
    "validator.asleepAfterAwake" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "「眠った」は「目覚めた」より前である必要があります" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "\"Fell asleep\" must be earlier than \"Woke up\"" } }
    } },

    "notification.bedtimeReminder.title" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "そろそろお休みの時間です" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Time to wind down" } }
    } },
    "notification.bedtimeReminder.body" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "おやすみ前にタップを忘れずに 🌙" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Don't forget to tap before bed 🌙" } }
    } },

    "pdf.title" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "睡眠リズム表" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Sleep Rhythm Chart" } }
    } },
    "pdf.period %@ %@" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "期間: %1$@ 〜 %2$@" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Period: %1$@ – %2$@" } }
    } },
    "chart.am" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "午前" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "AM" } }
    } },
    "chart.pm" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "午後" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "PM" } }
    } },
    "chart.notes" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "備考欄" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Notes" } }
    } },

    "就寝中: %@ 〜" : { "extractionState" : "manual", "localizations" : {
      "ja" : { "stringUnit" : { "state" : "translated", "value" : "就寝中: %@ 〜" } },
      "en" : { "stringUnit" : { "state" : "translated", "value" : "In bed since %@" } }
    } }
  }
}
```

(About 60 keys. The bilingual setting strings — "言語 / Language", "System (システム)", "再起動が必要 / Restart Required", and the alert message — are intentionally identical in `ja` and `en` so they read clearly mid-language-transition.)

- [ ] **Step 2: Validate JSON**

Run: `python3 -m json.tool SleepRecord/Localizable.xcstrings > /dev/null`
Expected: no output (file parses cleanly).

- [ ] **Step 3: Build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`. The catalog compiles into `ja.lproj/Localizable.strings` and `en.lproj/Localizable.strings` inside the `.app`.

- [ ] **Step 4: Verify both lproj directories exist**

Run:

```bash
ls "/Users/ryan/Library/Developer/Xcode/DerivedData/SleepRecord-ddmwrmmbtucbvydtevhibasogwyw/Build/Products/Debug-iphonesimulator/SleepRecord.app/" | grep lproj
```

Expected: at least `ja.lproj` and `en.lproj`.

- [ ] **Step 5: Run tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Expected: `Executed 42 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add SleepRecord/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
i18n: fill English translations in Localizable.xcstrings

~60 keys covering Home, Chart, Settings, MorningCorrection, DayEdit,
PDFExport, validator messages, notification body, and the language
picker section. Bilingual settings labels intentionally identical
across ja/en so they read clearly during the language transition.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `LocalizationCoverageTests`

**Goal:** Lock in the 4 validator EN translations against accidental deletion. Catches a missing key at test time rather than at runtime in front of an English user.

**Files:**
- Create: `SleepRecordTests/LocalizationCoverageTests.swift`

- [ ] **Step 1: Write the test file**

Path: `SleepRecordTests/LocalizationCoverageTests.swift`

```swift
import XCTest
@testable import SleepRecord

/// Verifies that the en.lproj resources contain real (non-fallback) translations
/// for the validator message keys. If a key is missing, iOS's
/// localizedString(forKey:value:table:) returns the `value` parameter we pass in.
final class LocalizationCoverageTests: XCTestCase {

    /// Returns the en-localized bundle, or nil if the test target doesn't bundle it.
    func enBundle() -> Bundle? {
        guard let path = Bundle.main.path(forResource: "en", ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }

    func assertEnglish(_ key: String, file: StaticString = #file, line: UInt = #line) {
        guard let bundle = enBundle() else {
            XCTFail("en.lproj missing from bundle — Localizable.xcstrings may not be compiled with en", file: file, line: line)
            return
        }
        let sentinel = "<__missing__>"
        let translated = bundle.localizedString(forKey: key, value: sentinel, table: nil)
        XCTAssertNotEqual(translated, sentinel, "key '\(key)' has no en translation", file: file, line: line)
        XCTAssertFalse(translated.isEmpty, "key '\(key)' has empty en translation", file: file, line: line)
    }

    func testValidator_BedWindowInverted_HasEnglish() {
        assertEnglish("validator.bedWindowInverted")
    }

    func testValidator_AsleepBeforeBedIn_HasEnglish() {
        assertEnglish("validator.asleepBeforeBedIn")
    }

    func testValidator_AwakeAfterBedOut_HasEnglish() {
        assertEnglish("validator.awakeAfterBedOut")
    }

    func testValidator_AsleepAfterAwake_HasEnglish() {
        assertEnglish("validator.asleepAfterAwake")
    }
}
```

- [ ] **Step 2: Regenerate project**

Run: `xcodegen generate`
Expected: `Created project at SleepRecord.xcodeproj`.

- [ ] **Step 3: Run tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Expected: `Executed 46 tests, with 0 failures`. (42 + 4 new.)

- [ ] **Step 4: Commit**

```bash
git add SleepRecordTests/LocalizationCoverageTests.swift \
        SleepRecord.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
i18n: add LocalizationCoverageTests for validator EN keys

4 cases assert that en.lproj contains real translations (not the
fallback sentinel) for each validator message key. Catches accidental
deletion or rename in the catalog.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Manual visual smoke test

**Goal:** Verify on the simulator that JP behavior is unchanged and EN renders correctly. No code, no commit — pure verification.

- [ ] **Step 1: Boot iPhone 17e (iOS 26.4)**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl boot BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B 2>/dev/null; \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl bootstatus BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B -b
```

Expected: device boots or `Device already booted, nothing to do.`

- [ ] **Step 2: Reinstall and launch (still in JP)**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B com.ryan.sleeprecord 2>/dev/null
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl uninstall BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B com.ryan.sleeprecord 2>/dev/null
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl install BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B \
  /Users/ryan/Library/Developer/Xcode/DerivedData/SleepRecord-ddmwrmmbtucbvydtevhibasogwyw/Build/Products/Debug-iphonesimulator/SleepRecord.app
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B com.ryan.sleeprecord
```

Verify: home screen still shows "おやすみ", "タップで入床時刻を記録", date in Japanese format.

- [ ] **Step 3: Force English via simctl + relaunch**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B com.ryan.sleeprecord 2>/dev/null
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B com.ryan.sleeprecord -AppleLanguages '("en")'
```

Then screenshot:

```bash
sleep 2
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B screenshot /tmp/sleeprecord-en.png
```

Read `/tmp/sleeprecord-en.png`. Expect:
- Big button reads "Good night" instead of "おやすみ"
- Subtitle reads "Tap to record bedtime"
- Tabs read "Home" / "Chart"
- Top banner still reads "SLEEP RHYTHM" (it's already English)

If any string still shows in Japanese, look up its source key in `Localizable.xcstrings` — the most common cause is the source string in code doesn't exactly match the key in the catalog (whitespace, punctuation).

- [ ] **Step 4: Test the in-app language Picker**

Tap the gear icon → Settings → 言語 / Language. Switch to "日本語". Restart alert appears. Tap OK. Kill the app and relaunch:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B com.ryan.sleeprecord
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch BD01070C-3F6E-4AF0-A57F-ADA207FE4A0B com.ryan.sleeprecord
```

Verify: app opens in Japanese, even though we launched without `-AppleLanguages '("en")'`. (The Picker wrote `["ja"]` to UserDefaults; iOS reads it on launch.)

- [ ] **Step 5: Test the System reset**

Switch the Picker back to "System (システム)". Restart. Verify: app opens in the simulator's actual locale (`ja-JP` by default), with no override.

If all five behaviors are correct, the implementation is complete. If anything fails, stop and propose a fix before declaring done.

---

## Out of scope

- More than two languages (zh-Hans, ko, etc.). New `*.xcstrings` localizations can be added later without changing call sites.
- Right-to-left layout — neither ja nor en is RTL.
- Plurals / stringsdict — no count-dependent strings in the inventory.
- Native-speaker translation review — translations are a best-effort first pass; users can edit `.xcstrings` directly to refine.
- Live language switching without restart — explicit non-goal per spec §4.3.
- Sync `AppleLanguages` choice across devices — explicitly per-device per spec §4.4.

## Self-review

**Spec coverage**

| Spec section | Where in plan |
|---|---|
| §2 Goals: full UI ja/en | Task 1 (catalogs), Task 2 (service-layer), Task 5 (translations) |
| §2 Goals: language Picker in Settings | Task 4 |
| §2 Goals: bundle display name ja/en | Task 1 (`InfoPlist.xcstrings`) |
| §3.1 String Catalog as mechanism | Task 1 |
| §3.2 file layout (`Localizable` + `InfoPlist` xcstrings) | Task 1 |
| §3.3 SwiftUI auto-lookup, no call-site change | Task 5 (translations land; the `Text("…")` calls were already in this form pre-i18n) |
| §3.4 Service-layer `String(localized:)` form | Task 2 |
| §4.1 Settings UI design | Task 4 |
| §4.2 `LanguagePreference` API + UserDefaults keys | Task 3 |
| §4.3 restart-based applies | Task 4 alert + Task 7 verification |
| §4.4 not synced via CloudKit | No code change needed (UserDefaults.standard is already device-local). Documented in spec only. |
| §5.1 string inventory ~55 keys | Task 5 (~60 keys including PDF + bilingual settings) |
| §6.1 SwiftUI date formatting auto-locale | No code change needed; verified in Task 7 Step 3 screenshot |
| §6.2 PDF formatter `.locale = .current` | Task 2 Step 3d |
| §6.3 `AppleLanguages` override propagates to `Locale.current` | Task 7 Step 3 verifies via simctl |
| §7.1 Info.plist `CFBundleLocalizations` + remove hardcoded display name | Task 1 Step 3 |
| §7.2 project.yml unchanged | Task 1 (no edit), confirmed in file map |
| §8.1 LanguagePreferenceTests (3) + LocalizationCoverageTests (4) | Tasks 3 + 6 |
| §8.2 visual smoke procedure | Task 7 |
| §8.3 SleepRecordValidatorTests update for locale stability | Task 2 Step 5 |

No gaps. Test count progression: 39 → 39 (Task 1) → 39 (Task 2) → 42 (Task 3) → 42 (Tasks 4,5) → 46 (Task 6).

**Placeholder scan**

No "TBD"/"TODO"/"implement later". Every code block is complete. Every `String(localized:)` key is also defined as a key in the Task 5 catalog.

**Type / API consistency**

- `LanguagePreference.shared` (singleton) referenced in Task 4 step 2; defined in Task 3 step 3 — match.
- `LanguagePreference.userPrefKey` / `.appleLanguagesKey` referenced in Task 3's tests — defined as `static let` in Task 3 step 3 — match.
- `LanguageOption.system / .japanese / .english` cases used in both Task 3 (LanguagePreference) and Task 4 (Picker tags) — defined once in Task 3 step 3 — match.
- All `String(localized: "<key>", defaultValue: ...)` keys in Task 2 (`validator.*`, `notification.bedtimeReminder.*`, `pdf.title`, `pdf.period`, `chart.am/pm/notes`) are present as keys in the catalog in Task 5 — match.
- `pdf.period %@ %@` uses positional placeholders (`%1$@ %2$@`) in Task 5 — matches the two-`%@` form Task 2 step 3b emits via interpolation.
- File path `SleepRecord/Services/LanguagePreference.swift` — referenced identically across Tasks 3, 4 (import not needed; same module).
