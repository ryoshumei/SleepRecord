# SleepRecord 中途覚醒 (Mid-sleep Awakening) — 設計書

- **Date**: 2026-05-05
- **Status**: 設計確定（実装未着手）
- **Owner**: Ryan
- **Plan**: `docs/superpowers/plans/2026-05-05-mid-sleep-awakening.md` (to be written)
- **Mockup**: `docs/superpowers/mockups/2026-05-05-mid-sleep-awakening-chart.html`
- **Last updated**: 2026-05-05 — 初版

## 1. 概要

睡眠中の途中覚醒（中途覚醒 / mid-sleep awakening）を記録できるようにする。親 spec（`2026-05-04-sleep-rhythm-chart-design.md`）の v1 では入床/入眠/覚醒/起床の 4 時刻のみで、夜間に何度も起きるユーザのデータが捉えられなかった。本 spec で `WakeEvent` 子レコードを追加し、ホーム画面のタップ操作で記録できるようにする。

**プライマリ・ユースケース**: 夜中に目が覚めたとき、ベッドの中でアプリを開き「目覚めた」をタップ。再び眠れそうなときに「再び眠る」をタップ。これを朝までに何度繰り返してもよく、朝に「おはよう」を押すと未クローズの覚醒も自動でクローズされる。医師に提出する PDF / 画面チャートで、夜中の覚醒回数と総覚醒時間が即座に読み取れる。

## 2. ゴールと非ゴール

### Goals (v1.3)
- 夜間覚醒を **タップ 2 回**（目覚めた / 再び眠る）で記録できる
- ホーム画面の状態に応じてボタンが切り替わる（既存の 2 タップ UX を踏襲）
- 朝の補正シート (`MorningCorrectionSheet`) と日次編集シート (`DayEditSheet`) で覚醒イベントを **編集・追加・削除** できる
- チャート / PDF で覚醒中のセルが **眠り（黒斜線）として描かれない** — 自然な「赤のみ」になる
- 備考欄に **`覚醒×N (M分)`** の自動サマリが付く（ユーザの自由記述メモは下に併記）
- 既存の 46 ユニットテストは regress させず、+13 ケース追加して **59 ケース** にする
- 既存ローカライズ機構（ja/en）に新キーを追加して両言語で動く
- CloudKit 同期を維持（追加スキーマは additive、既存 v1 データは `wakeEvents = []` で読める）

### Non-goals (v1.3)
- セルへの **▼ や ▲ など特別マーカー** — 「布団にいるが起きている」セルと中途覚醒セルは同じ視覚（赤のみ）。区別はデータモデルと備考欄サマリにのみ存在する。
- 覚醒中の **通知 / リマインダー**（「30 分経ったら布団から出ましょう」など） — v2 候補
- 統計画面（覚醒回数の月平均、平均覚醒時間など） — v2 候補
- Apple Watch / HealthKit 連携での自動検出 — v2 候補
- 覚醒理由のカテゴリ化（トイレ / 悪夢 / 騒音 など） — 自由記述メモで運用、必要なら v2 で別 spec
- 複数形対応（1 wake vs 2 wakes の文法変化） — `Wakes×N` テンプレートで運用、必要なら v2

## 3. データモデル

### 3.1 新規モデル `WakeEvent`

```swift
import SwiftData
import Foundation

@Model
final class WakeEvent {
    // CloudKit 制約: 全 non-optional 属性に property-level デフォルト
    var id: UUID = UUID()
    var startedAt: Date = Date.distantPast
    var endedAt: Date?            // nil = 未クローズ（まだ覚醒中）
    var session: SleepSession?    // CloudKit が要求する optional inverse
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(
        startedAt: Date,
        endedAt: Date? = nil,
        session: SleepSession? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.session = session
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isOpen: Bool { endedAt == nil }
    var durationMinutes: Int? {
        guard let end = endedAt else { return nil }
        return Int(end.timeIntervalSince(startedAt) / 60)
    }
}
```

### 3.2 `SleepSession` への追加

```swift
@Relationship(deleteRule: .cascade, inverse: \WakeEvent.session)
var wakeEvents: [WakeEvent] = []
```

- `deleteRule: .cascade` — `SleepSession` を消すと関連 `WakeEvent` も消える
- 配列のデフォルト `= []` で v1 既存データの自動マイグレーションが成立する（CloudKit のスキーマ進化ルール）

### 3.3 不変条件（保存時に検証、§7 参照）

各 `WakeEvent` について:
1. `startedAt` と（`endedAt` が non-nil なら）`endedAt` の両方が `[bedInAt, bedOutAt]` の中に収まる
2. `startedAt < endedAt`（両方が non-nil のとき）
3. 同じ `SleepSession` 内の他のイベントと **時間が重ならない**

進行中（in-progress）セッション (`bedOutAt == nil`) では (1) の上限が緩む — `[bedInAt, .now]` で代用。

## 4. ホーム画面の状態と UI

### 4.1 状態マシンの拡張

`SleepStateMachine` の 4 状態 (`.empty` / `.inBed` / `.correctionPending` / `.completed`) は据え置き。新たに **派生 predicate** を追加:

```swift
extension SleepStateMachine {
    /// True iff the active session has at least one open WakeEvent.
    static func isAwakeMidSleep(activeSession: SleepSession?) -> Bool {
        guard let s = activeSession else { return false }
        return s.wakeEvents.contains { $0.isOpen }
    }
}
```

`.inBed` 状態の中で `isAwakeMidSleep` が true / false で UI が分岐する。

### 4.2 ボタン構成

| 状態 | 主ボタン (大円) | 副ボタン (小・下) |
|---|---|---|
| `.empty` / `.completed` | 🌙 おやすみ | — |
| `.inBed` 通常 | ☀️ おはよう | 🌗 **目覚めた / Woke up** *(新)* |
| `.inBed` + open WakeEvent | 🛏️ **再び眠る / Back to sleep**<br>(subtitle: "目覚めて 12分") *(新)* | ☀️ おはよう (副) |
| `.correctionPending` | 📝 補正する | — |

副ボタン (新) は通常の SwiftUI `Button` で、大円ボタンの下に小さめに表示。`.inBed` 状態でのみ可視。

### 4.3 タップフロー

1. ユーザが おやすみ をタップ → `SleepSession` 作成、状態 `.inBed`
2. 夜中に覚醒 → アプリを開く → ホーム下部に「🌗 目覚めた」副ボタンが見える → タップ
3. → `WakeEvent(startedAt: now)` を `activeSession.wakeEvents` に追加（save）
4. → ホーム UI が「🛏️ 再び眠る」モードに切り替わる、subtitle に「目覚めて %@」（経過時間）
5. ユーザが再び眠るタイミングで「再び眠る」をタップ → 一番新しい open WakeEvent の `endedAt = now` をセット（save）
6. → ホーム UI が `.inBed` 通常に戻る、副ボタン「目覚めた」が再出現
7. 2–6 を朝まで何度繰り返してもよい
8. 朝、ユーザが おはよう をタップ → 全ての open `WakeEvent` を `endedAt = now` で自動クローズ（save）→ 既存フロー（`bedOutAt = now`、補正シート提示）

### 4.4 経過時間表示

「目覚めて %@」のサブタイトルは、ホーム画面の既存 `.onReceive(timer)` (30 秒ごと) を流用してリアルタイム更新。具体表記は `format: .timer` でなく自前の `分` 表記:
- 1 分未満: 「目覚めて 1 分未満」
- 60 分未満: 「目覚めて 12 分」
- 60 分以上: 「目覚めて 1 時間 23 分」

## 5. 補正シート / 編集シートの拡張

### 5.1 `MorningCorrectionSheet` (`Views/Home/`)

既存セクション群の後ろ、備考の前に **「中途覚醒 / Mid-sleep awakenings」** セクションを追加。

レイアウト:
- イベントが 0 個: 「（なし） / (none)」プレースホルダ + 「+ 追加 / Add」ボタン
- イベントが N 個: 各イベント 1 行 = 開始時刻 DatePicker + 終了時刻 DatePicker + 削除ボタン (赤・小)、最後に「+ 追加」

### 5.2 `DayEditSheet` (`Views/Chart/`)

過去日の編集にも同等のセクションを追加。挙動は §5.1 と同じ。日付フィールド経由で読み込む既存セッションがあれば `wakeEvents` も同じセッションに紐づく。

### 5.3 削除と追加

- 削除: シート内で行の削除ボタン → `modelContext.delete(event)` → save
- 追加: `+` → 新規 `WakeEvent(startedAt: midpoint, endedAt: midpoint+10min)` を作成（中央時刻のデフォルト）→ ユーザが時刻を編集 → save

## 6. チャート / PDF 描画への影響

### 6.1 セル描画ルール（拡張）

`ChartCellCalculator.cells(forDay:sessions:)` の "any-overlap = mark" ルールを拡張:

- **`inBed` 層**: 変更なし。`[bedInAt, bedOutAt]` がセルと重なれば true。
- **`asleep` 層**: `[asleepAt, awakeAt]` がセルと重なる **かつ** 同じセッションの `WakeEvent` のいずれともセルが重ならない場合に true。`WakeEvent` が open のときは `[startedAt, .now]` をその範囲とみなす。

擬似コード:

```swift
for hour in 0..<24 {
    let cellRange = hour..<(hour + 1)時間
    cells[hour].inBed = ...既存の判定 (unchanged)...
    if cells[hour].inBed,
       let asleep = session.asleepAt,
       let awake = session.awakeAt,
       asleep < awake,
       overlap(asleep..<awake, cellRange) {
        let interrupted = session.wakeEvents.contains { e in
            let endR = e.endedAt ?? .now
            guard e.startedAt < endR else { return false }
            return overlap(e.startedAt..<endR, cellRange)
        }
        cells[hour].asleep = !interrupted
    }
}
```

`Range<Date>` は `lower > upper` で trap するので、親 spec §11.1 の guarded-construct を踏襲（`startedAt < endR` チェック）。

### 6.2 視覚上の意味

- 既存の「布団にいるが起きている」セル（赤のみ、就寝前 / 起床後の bookend）と中途覚醒セルは **同じ見た目**（赤のみ）。物理的に同じ状態（布団内・覚醒）だから。
- 視覚的な特別マーカー（▼ など）は **入れない**。区別はデータモデルと備考欄サマリで提供。
- 結果として、夜中の覚醒は **眠り（斜線）の連続が途切れる赤のギャップ** として読める（モックアップ参照）。

### 6.3 備考欄サマリ

`ChartCellCalculator.notes(forDay:sessions:)` 拡張:
- セッションに 1 つでも `WakeEvent` があれば、ユーザ記述の前に **`覚醒×N (M分)`** をプレフィックスで追加
- N = そのセッションの全イベント数（open 含む）
- M = 全イベントの合計分数（open イベントは `now - startedAt`）
- すべて open のときは `(進行中)` / `(open)` を付加: `覚醒×1 (進行中)`
- ja: `覚醒×%1$d (%2$d分)`、en: `Wakes×%1$d (%2$dm)`

PDF 側 (`PDFExporter`) は `ChartCellCalculator.notes()` の戻り値をそのまま描画するので、自動でサマリが乗る。

## 7. バリデーション

### 7.1 新規 Issue

`SleepRecordValidator.Issue` に 3 ケース追加:

```swift
case wakeEventOutOfBounds  // 開始/終了が [bedInAt, bedOutAt] の外
case wakeEventOverlap       // 同一セッションの他イベントと重なる
case wakeEventInverted     // startedAt >= endedAt
```

### 7.2 関数追加

```swift
static func validateWakeEvents(
    _ events: [(startedAt: Date, endedAt: Date?)],
    bedInAt: Date,
    bedOutAt: Date
) -> Issue?
```

返り値が non-nil なら最初のエラー。`MorningCorrectionSheet` / `DayEditSheet` の保存ボタン無効化に使う。

### 7.3 メッセージ

3 つ追加:
| Issue | ja | en |
|---|---|---|
| `wakeEventOutOfBounds` | 中途覚醒の時刻は入床〜起床の範囲内に収めてください | Mid-sleep awakening must fall within the bed window |
| `wakeEventOverlap` | 中途覚醒の時間が他のイベントと重なっています | Mid-sleep awakenings cannot overlap |
| `wakeEventInverted` | 中途覚醒の終了時刻は開始時刻より後である必要があります | Awakening end must be after start |

## 8. ローカライズ追加キー

| Key | ja | en |
|---|---|---|
| `目覚めた` | 目覚めた | Woke up |
| `再び眠る` | 再び眠る | Back to sleep |
| `wake.elapsed.minutesUnder1` | 目覚めて 1分未満 | Awake for under 1m |
| `wake.elapsed.minutes` (`%d`) | 目覚めて %d分 | Awake for %dm |
| `wake.elapsed.hoursMinutes` (`%1$d %2$d`) | 目覚めて %1$d時間%2$d分 | Awake for %1$dh %2$dm |
| `中途覚醒` | 中途覚醒 | Mid-sleep awakenings |
| `（なし）` | （なし） | (none) |
| `追加` | 追加 | Add |
| `wake.summary` (`%1$d %2$d`) | 覚醒×%1$d (%2$d分) | Wakes×%1$d (%2$dm) |
| `wake.summary.open` | 覚醒×%1$d (進行中) | Wakes×%1$d (open) |
| `validator.wakeEventOutOfBounds` | (上記) | (上記) |
| `validator.wakeEventOverlap` | (上記) | (上記) |
| `validator.wakeEventInverted` | (上記) | (上記) |

合計 **+13 キー**（既存 ~60 → ~73）。

## 9. テスト戦略

### 9.1 新規ケース

| Suite | 追加 | カバー内容 |
|---|---:|---|
| `WakeEventTests` (新) | 3 | open/closed の判定、duration 計算、cascade-delete 経由で SleepSession 削除時に自動 cleanup |
| `ChartCellCalculatorTests` (拡張) | 3 | 1 イベントが asleep セルを赤に戻す / 複数イベント / open イベント on in-progress day |
| `SleepStateMachineTests` (拡張) | 1 | `isAwakeMidSleep` predicate |
| `SleepRecordValidatorTests` (拡張) | 3 | wakeEventOutOfBounds / wakeEventOverlap / wakeEventInverted の各エラーパス |
| `LocalizationCoverageTests` (拡張) | 3 | 3 つの新 validator キーが en.lproj に存在することを assert |
| **合計** | **+13** | 46 → **59** ケース |

### 9.2 既存テストへの影響

`ChartCellCalculatorTests` の既存 13 ケースは wake events なしのデータ。追加した拡張ロジックは「wake events が空なら影響しない」設計なので regress しない想定。実装後にフル run で確認。

`LocalizationCoverageTests` は validator EN キーの存在を assert。3 つの新キー (`validator.wakeEventOutOfBounds` 等) を追加して既存パターンを踏襲。

### 9.3 視覚スモーク

iPhone 17e iOS 26.4 シミュレータで:
1. JP モード: おやすみ → 目覚めた → 再び眠る → 目覚めた → おはよう → 補正シートで 2 イベント表示確認 → 保存 → チャートで赤ギャップ確認 → PDF プレビューで備考欄サマリ確認
2. EN モード: 同じ手順、ボタンとサマリが英語表記に切り替わっていることを確認

## 10. ファイル構成（差分）

```
SleepRecord/
├── Models/
│   ├── SleepSession.swift                        ← @Relationship 追加
│   └── WakeEvent.swift                           ← 新規
├── Services/
│   ├── SleepStateMachine.swift                   ← isAwakeMidSleep predicate 追加
│   ├── ChartCellCalculator.swift                 ← cells/notes 拡張
│   └── SleepRecordValidator.swift                ← 3 Issue + validateWakeEvents
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift                        ← 副ボタン + 再び眠る切替
│   │   └── MorningCorrectionSheet.swift          ← 中途覚醒セクション
│   └── Chart/
│       └── DayEditSheet.swift                    ← 中途覚醒セクション
└── Localizable.xcstrings                         ← +13 キー

SleepRecordTests/
├── WakeEventTests.swift                          ← 新規 (3 ケース)
├── ChartCellCalculatorTests.swift                ← +3 ケース
├── SleepStateMachineTests.swift                  ← +1 ケース
├── SleepRecordValidatorTests.swift               ← +3 ケース
└── LocalizationCoverageTests.swift               ← +3 keys (validator)

docs/superpowers/
├── specs/
│   └── 2026-05-05-mid-sleep-awakening-design.md   ← 本ファイル
├── plans/
│   └── 2026-05-05-mid-sleep-awakening.md          ← 後で追加
└── mockups/
    └── 2026-05-05-mid-sleep-awakening-chart.html  ← 既にコミット済み (今コミット)
```

`project.yml` 変更なし（既存 `sources: [{path: SleepRecord}]` が再帰検索で `WakeEvent.swift` と新規テストを拾う）。`xcodegen generate` を新規 .swift 追加後に 1 回実行。

## 11. CloudKit 同期 / マイグレーション

### 11.1 v1 既存データの読み込み

SwiftData の暗黙マイグレーション:
- 既存 `SleepSession` レコードは新しい `wakeEvents` プロパティを参照しても `[]` を返す（プロパティレベルデフォルトのおかげ）
- 既存ユーザのデバイスで初回起動時にスキーマ拡張が自動的に行われる
- iCloud 経由で他デバイスに同期されるときも、新スキーマが優先される

### 11.2 同時編集

既存 v1 と同じく SwiftData の暗黙的競合解消（last-write-wins）に任せる。中途覚醒イベントは時刻ベースの独立レコードなので、同時編集の意味的衝突は起きにくい。

## 12. エッジケース

| ケース | 扱い |
|---|---|
| 「目覚めた」をタップ後、再び眠るのを忘れて次の朝まで放置 | おはようタップで自動クローズ（`endedAt = now`）。覚醒時間が実際より長く出るが、補正シートで修正可能 |
| ユーザが「再び眠る」を 2 連続タップ（誤操作）→ 同じ event を 2 回クローズ | `endedAt` が既に non-nil なら無視（idempotent）|
| 「目覚めた」を 2 連続タップ → 0 秒の event が 2 つ | 1 回目で event 作成、2 回目で対応する「再び眠る」が UI に表示されているはず（ボタン切替が遅延しても、2 回目のタップは「再び眠る」になる）。タイミング次第で 2 events が生まれた場合: バリデーションで overlap として検出 → 補正シートで 1 つを削除 |
| ユーザが補正シートで覚醒時刻を入床より前にセット | `wakeEventOutOfBounds` エラー、保存ボタン無効化 |
| 覚醒イベントが 24h を跨ぐ | `[startedAt, endedAt]` のレンジ判定はそのまま機能。チャートの該当全セルが赤になる（hatch 抜け） |
| 進行中セッションで現在時刻が `endedAt` 上限になる | `Range<Date>` trap を避けるため `startedAt < .now` を guard（既存の defensive check と同様） |
| iCloud 未設定で在使用中に切り替え | データ層と UI は無関係。WakeEvent も同じローカル/CloudKit/in-memory の 3 段フォールバックで動く |

## 13. オープンクエスチョン (resolved)

- **覚醒中の通知?** → out of scope。v2 候補
- **覚醒理由のカテゴリ化?** → out of scope。自由記述メモで運用
- **▼ などのセル特別マーカー?** → 不採用。チャート視覚は二層ルールのみ、サマリは備考欄

## 14. 変更履歴

- **2026-05-05 (初版)**: WakeEvent モデル、タップ 2 回 UX、チャートは hatch 抜けで表示（特別マーカー無し）、備考欄に自動サマリ で確定。HTML モックアップ併設。
