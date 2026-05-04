# Chart 備考欄 Per-Row Borders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each date row in the chart's `備考欄` (notes) column a visible per-row border so 24-hour cells + notes read as one continuous gridded table on screen and in PDF.

**Architecture:** Pure SwiftUI overlay border on the existing `Text(notes)` view in `DayRowView`; per-row `UIBezierPath` rect drawn inside the existing day-loop in `PDFExporter`, replacing the current outer-only column border. No service-layer changes; no schema or data flow changes; no new tests (existing 39 still cover all behavior).

**Tech Stack:** SwiftUI, PDFKit, UIKit Bezier paths.

**Spec reference:** `docs/superpowers/specs/2026-05-04-sleep-rhythm-chart-design.md` (§4.2, §8, §15 v1.1 changelog)

**Build / test invocations (used in verify steps):**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

```bash
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
| `SleepRecord/Views/Chart/DayRowView.swift` | Add `.overlay(Rectangle().stroke(...))` to the notes cell so each on-screen row has a bordered 備考欄. |
| `SleepRecord/Services/PDFExporter.swift` | Replace the single outer `notesBodyRect` rectangle with a per-row 0.3 pt rect drawn inside the existing `for (idx, day)` loop. |

No new files. No test files. No `project.yml` change (no new sources, so `xcodegen generate` is not required).

---

## Task 1: Add row border to on-screen 備考欄 cells

**Files:**
- Modify: `SleepRecord/Views/Chart/DayRowView.swift:34-40`

**Why this works:** The existing `Text(notes)` already has a fixed `frame(width: notesWidth, height: rowHeight)` with `padding(.leading, 4)`. Mirroring the chart-header pattern at `ChartView.swift:36-41` — `frame → padding → overlay(Rectangle().stroke)` — wraps the (frame + 4 pt left padding) region in a border. Border width (84 pt = `notesWidth + 4`) matches the header banner's bordered region, so they vertically align. Empty notes still draw the border because the frame occupies space regardless of text content; `foregroundStyle(.clear)` only hides text.

- [ ] **Step 1: Read the current file to confirm line numbers**

Run: `Read SleepRecord/Views/Chart/DayRowView.swift`
Expected: line 34 begins `Text(notes)`, the chain ends at line 40 with `.truncationMode(.tail)`.

- [ ] **Step 2: Apply the edit**

Replace this block (lines 34-40):

```swift
            Text(notes)
                .font(.system(size: 9))
                .foregroundStyle(notes.isEmpty ? .clear : .primary)
                .frame(width: notesWidth, height: rowHeight, alignment: .topLeading)
                .padding(.leading, 4)
                .lineLimit(2)
                .truncationMode(.tail)
```

with:

```swift
            Text(notes)
                .font(.system(size: 9))
                .foregroundStyle(notes.isEmpty ? .clear : .primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(width: notesWidth, height: rowHeight, alignment: .topLeading)
                .padding(.leading, 4)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 0.4))
```

Why the modifier order moved: `.lineLimit` and `.truncationMode` apply to the underlying `Text`, so they belong before `.frame`. The new `.overlay(...)` must come **after** `.padding(.leading, 4)` so the border encloses the full 84 pt region (matching the banner header).

- [ ] **Step 3: Quick syntax / type check**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --sdk iphonesimulator \
  swiftc -typecheck -target arm64-apple-ios26.4-simulator \
  SleepRecord/Models/*.swift SleepRecord/Services/*.swift SleepRecord/Utilities/*.swift \
  SleepRecord/Views/Home/*.swift SleepRecord/Views/Chart/*.swift \
  SleepRecord/Views/Settings/*.swift SleepRecord/Views/PDF/*.swift \
  SleepRecord/SleepRecordApp.swift
```

Expected: no output (typecheck succeeds). If errors mention `Cannot find 'Rectangle'` or `'Color'`, the file already imports `SwiftUI` so this should not happen — re-read the file to confirm `import SwiftUI` at line 1.

- [ ] **Step 4: Full xcodebuild**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Run all tests (regression)**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test
```

Expected: `** TEST SUCCEEDED **`, `Executed 39 tests, with 0 failures`. Visual rendering is not test-covered (snapshot tests are out of scope per spec §12.2), so test count is unchanged.

- [ ] **Step 6: Commit**

```bash
git add SleepRecord/Views/Chart/DayRowView.swift
git commit -m "$(cat <<'EOF'
Chart: add per-row border to 備考欄 cells (screen)

Each date row's notes cell now has the same thin black border (lineWidth 0.4)
as the 24 hour cells, so the chart reads as one continuous gridded table.
Empty cells keep the border (anchors the column visually).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds.

---

## Task 2: Replace PDF outer column border with per-row cell borders

**Files:**
- Modify: `SleepRecord/Services/PDFExporter.swift:169-208`

**Why this works:** The existing data-row `for (idx, day)` loop already computes each row's `y` position. Adding one `UIBezierPath(rect:)` stroke per iteration draws a 0.3 pt rectangle around that row's notes cell, matching the line weight `drawCell` already uses for hour cells (`PDFExporter.swift:221`). Stacked rectangles share edges; at 0.3 pt the overlap is invisible. Removing the outer `notesBodyRect` block prevents drawing a heavier line at the top/bottom edges.

- [ ] **Step 1: Read the current file to confirm line numbers**

Run: `Read SleepRecord/Services/PDFExporter.swift`
Expected: line 169 begins `for (idx, day) in days.enumerated() {`, line 202-208 contains the `// Border around the notes column body` block.

- [ ] **Step 2: Add per-row notes cell border inside the day loop**

Inside the `for (idx, day) in days.enumerated()` loop, **after** the hour-cells inner loop and **before** the existing `let notes = calc.notes(...)` block, insert:

```swift
            // Notes cell border (per-row, matches drawCell line weight)
            let notesCellRect = CGRect(
                x: notesLeft, y: y,
                width: notesColumnWidth, height: cellHeight
            )
            UIColor.black.setStroke()
            let notesCellBorder = UIBezierPath(rect: notesCellRect)
            notesCellBorder.lineWidth = 0.3
            notesCellBorder.stroke()
```

Concretely the loop body becomes (showing surrounding context):

```swift
        for (idx, day) in days.enumerated() {
            let y = chartTop + CGFloat(idx) * cellHeight
            let label = formatter.string(from: day) as NSString
            label.draw(at: CGPoint(x: pageMargin, y: y + 2), withAttributes: labelAttrs)

            let cells = calc.cells(forDay: day, sessions: sessions)
            for (h, cell) in cells.enumerated() {
                let x = chartLeft + CGFloat(h) * cellWidth
                let cellRect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                drawCell(rect: cellRect, cell: cell)
            }

            // Notes cell border (per-row, matches drawCell line weight)
            let notesCellRect = CGRect(
                x: notesLeft, y: y,
                width: notesColumnWidth, height: cellHeight
            )
            UIColor.black.setStroke()
            let notesCellBorder = UIBezierPath(rect: notesCellRect)
            notesCellBorder.lineWidth = 0.3
            notesCellBorder.stroke()

            let notes = calc.notes(forDay: day, sessions: sessions)
            if !notes.isEmpty {
                let notesRect = CGRect(
                    x: notesLeft,
                    y: y + 1,
                    width: notesColumnWidth,
                    height: cellHeight - 1
                )
                (notes as NSString).draw(in: notesRect, withAttributes: notesAttrs)
            }
        }
```

- [ ] **Step 3: Remove the outer notes-column border block**

Delete this block (currently `PDFExporter.swift:202-208`):

```swift
        // Border around the notes column body
        let notesBodyRect = CGRect(x: notesLeft, y: chartTop,
                                    width: notesColumnWidth,
                                    height: CGFloat(days.count) * cellHeight)
        let notesBorder = UIBezierPath(rect: notesBodyRect)
        notesBorder.lineWidth = 0.5
        notesBorder.stroke()
```

The per-row rectangles inserted in Step 2 collectively form the same outer rectangle (top, left, right, bottom edges all drawn by row 0 / row N / column endpoints), but at the matching 0.3 pt weight instead of 0.5 pt.

- [ ] **Step 4: Quick syntax / type check**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --sdk iphonesimulator \
  swiftc -typecheck -target arm64-apple-ios26.4-simulator \
  SleepRecord/Models/*.swift SleepRecord/Services/*.swift SleepRecord/Utilities/*.swift \
  SleepRecord/Views/Home/*.swift SleepRecord/Views/Chart/*.swift \
  SleepRecord/Views/Settings/*.swift SleepRecord/Views/PDF/*.swift \
  SleepRecord/SleepRecordApp.swift
```

Expected: no output.

- [ ] **Step 5: Full xcodebuild**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Run all tests (regression)**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test
```

Expected: `Executed 39 tests, with 0 failures`. `PDFLayoutBuilderTests` (5 cases) covers `pages(totalDays:)` only — drawing changes don't affect that pure function.

- [ ] **Step 7: Commit**

```bash
git add SleepRecord/Services/PDFExporter.swift
git commit -m "$(cat <<'EOF'
Chart PDF: per-row borders on 備考欄 cells

Replace the single 0.5pt outer notes-column rectangle with a 0.3pt
rectangle per data row, matching the hour-cell line weight. Stacked
rectangles share edges, so the outer column outline is preserved.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds.

---

## Task 3: Manual visual verification

The SwiftUI changes in Task 1 have no automated test coverage (UI snapshot tests are out of scope per spec §12.2), so a smoke test on the simulator and a one-page PDF inspection are the safety net. This task does NOT modify code or commit.

- [ ] **Step 1: Boot the simulator with the build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SleepRecord.xcodeproj -scheme SleepRecord \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO build
```

Then launch the app in the iPhone 17 simulator (open Simulator.app → run from Xcode UI, or `xcrun simctl install/launch`). Tell the user the build is ready and ask them to manually verify on the chart tab.

- [ ] **Step 2: User manually verifies — chart tab**

Ask the user to confirm:
1. Open the チャート tab.
2. Each date row in the 備考欄 column shows a thin black border around the cell (visible even when the row has no note text).
3. The border's width matches the 備考欄 banner above it (no horizontal jog).
4. The border line weight visually matches the 24 hour cells to the left.

If any check fails: stop, report which one, and propose a fix before continuing.

- [ ] **Step 3: User manually verifies — PDF export**

Ask the user to:
1. Tap the PDF icon in the toolbar.
2. Use the default 1-month range and tap preview.
3. Confirm: each date row's 備考欄 cell has its own visible border, and the column outline is preserved (no missing outer edge).
4. Confirm: line weight is similar to (or matches) the hour-cell border weight, no obvious difference.

If any check fails: stop, report which one, and propose a fix before continuing.

- [ ] **Step 4: Stage spec doc changes for commit**

The spec was updated earlier in this branch (`docs/superpowers/specs/2026-05-04-sleep-rhythm-chart-design.md` — §4.2, §8, §15 v1.1 changelog, top-of-file Last-updated). Stage and commit it as a doc-only commit so spec, screen change, and PDF change form three reviewable commits.

```bash
git add docs/superpowers/specs/2026-05-04-sleep-rhythm-chart-design.md \
        docs/superpowers/plans/2026-05-04-chart-notes-row-borders.md
git commit -m "$(cat <<'EOF'
Spec/plan: 備考欄 per-row borders (v1.1 micro-tweak)

Document the table-grid intent for 備考欄: each date cell is bordered
matching the hour-cell weight, empty cells keep the border. Adds plan
file for the two-task implementation.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds. Three commits total on the branch (spec/plan, screen, PDF).

---

## Out of scope

- **Snapshot / pixel tests** — explicitly out of scope per spec §12.2.
- **Hour-numbers row notes spacer alignment** (`ChartView.swift:64`) — currently 80 pt vs banner/data-row 84 pt; the 4 pt offset is invisible because the spacer holds no border or text. Not part of this change.
- **PDF outer-border line weight** changing from 0.5 → 0.3 pt — this is a side effect of the per-row approach and matches hour cells. If the user wants the outer perimeter heavier, a separate plan can re-add a 0.5 pt outer rect after the per-row loop.

## Self-review

**Spec coverage**

- §4.2 "各日の備考欄セルは時間セルと同じ枠線で囲む（画面: lineWidth 0.4 / PDF: 0.3 pt）" → Task 1 (screen, 0.4) + Task 2 (PDF, 0.3). ✅
- §4.2 "備考が空のセルも枠線を残し" → Task 1 retains `foregroundStyle(.clear)` for empty notes; the bordered frame is independent of text. Task 2 draws the per-row rect unconditionally before the `if !notes.isEmpty` text-draw. ✅
- §8 "備考欄の枠線: 各行の備考セルは時間セルと同じ 0.3 pt 枠線で囲む（外周一括ではなく行ごと）" → Task 2 step 3 deletes the outer-only block; step 2 inserts per-row. ✅
- §15 v1.1 changelog — referenced by Task 3 step 4 commit message. ✅

**Placeholder scan**

No "TBD", "TODO", "implement later", or vague descriptions. All steps include exact code, exact paths (with line ranges), and exact commands with expected output.

**Type / API consistency**

- `Rectangle()`, `Color.black`, `lineWidth: 0.4` — all SwiftUI APIs already used at `DayRowView.swift:50` (CellView's hour-cell border).
- `UIBezierPath(rect:)`, `UIColor.black.setStroke()`, `lineWidth: 0.3` — all UIKit APIs already used at `PDFExporter.swift:218-221` (`drawCell`'s hour-cell border).
- `notesLeft`, `cellHeight`, `notesColumnWidth`, `chartTop` — already-bound locals in `drawChart`.

**No spec gap.** No ambiguous requirement. Plan is self-contained.
