# 睡眠リズム表 iOS App — 設計書

- **Date**: 2026-05-04
- **Status**: v1 実装完了（39 ユニットテスト通過、シミュレータ動作確認済）
- **Owner**: Ryan
- **Plan**: `docs/superpowers/plans/2026-05-04-sleep-rhythm-chart.md`
- **Last updated**: 2026-05-04 — 備考欄の各日セルに枠線を追加し時間セルと統一（v1.1 微調整）。チャート形式（AM/PM バナー + 0-11/0-11 + 備考欄カラム）、CloudKit/Range クラッシュ対応など反映

## 1. 概要

iOS 単体で動作する睡眠記録アプリ。日本の保育・医療現場で使われる伝統的な「睡眠リズム表」フォーマットでユーザ自身の睡眠を可視化し、医師への提出用に PDF 出力できる。

**プライマリ・ユースケース**: 自分の睡眠を毎日簡単に記録し、月単位のリズム表として PDF 化して通院時に医師へ渡す。

**ユーザ**: 単一ユーザ (プロフィール切替なし)。

## 2. ゴールと非ゴール

### Goals (v1)
- 「2タップで記録完了」を満たす日次入力 UX
- 「布団に入っていた時間」と「実際に眠っていた時間」を 2 層で可視化したチャート
- 月次チャートの PDF 出力（A4 縦、医師提出向け）
- iCloud 同期によるバックアップ

### Non-goals (v1)
- 複数ユーザ／家族メンバー切替
- HealthKit / Apple Watch 連携
- 昼寝（1日複数セッション）の本格サポート
- 睡眠統計（睡眠効率%、平均総睡眠時間など）
- 多言語対応（日本語のみ）
- iPad 専用最適化レイアウト（iPhone レイアウトで動く前提）

## 3. 技術スタック

| 項目 | 選定 |
|---|---|
| Min iOS | 26.4 (最新の iOS 26.4.1 まで対応) |
| 言語 | Swift 5.9+ |
| UI | SwiftUI |
| 永続化 | SwiftData |
| 同期 | CloudKit Private Database (SwiftData 経由) |
| PDF 生成 | PDFKit |
| 通知 | UserNotifications |
| 外部依存 | なし |

## 4. コアコンセプト

### 4.1 セル表記（チャートの 1 時間セル）

各セルは 2 層構造：
- **下半分**: 赤ベタ塗り = その時間に布団に入っていた
- **上半分**: 黒の斜線（ハッチング）= その時間に実際に眠っていた

セルの 4 状態：

| 上半分 | 下半分 | 意味 |
|---|---|---|
| 白 | 白 | 起きていた |
| 白 | 赤 | 布団にいたが起きていた |
| 黒斜線 | 赤 | 布団に入って実際に寝ていた |
| 黒斜線 | 白 | 布団以外（ソファ等）で寝ていた（稀） |

### 4.2 チャートレイアウト

参考にした伝統的な紙の睡眠リズム表に合わせた表組み形式：

```
+--------+-------------------+-------------------+--------+
|        |       午前        |       午後        | 備考欄 |
|        | 0 1 2 ... 9 10 11 | 0 1 2 ... 9 10 11 |        |
+--------+-------------------+-------------------+--------+
| 5/1(金)| ████░░░░░░░░░░░░░ | ░░░░░░░░░░░░░░░░░ | 寝つき悪い|
| 5/2(土)| ████░░░░░░░░░░░░░ | ░░░░░░░░░░░░░░░░░ |        |
...
```

- 1日 = 1行 = **24セル**（1セル = 1時間）。セル幅は固定。
- ヘッダー2段:
  - 上段（バナー）: **「午前」「午後」「備考欄」** をグレー背景＋枠線で表示
  - 下段（時刻数字）: 連続する 0-23 ではなく **「0-11 / 0-11」** にリセット（伝統的な紙のリズム表に合わせる）
- 12時境界には太線（AM/PM の視覚的区切り）
- **備考欄は右端の独立カラム**（チャートバーと同じ行に並ぶ）
  - 各日の備考欄セルは時間セルと**同じ枠線**で囲む（画面: `lineWidth 0.4` / PDF: `0.3 pt`）
  - 備考が空のセルも枠線を残し、24時間セル＋備考欄が一体の表組みとして見える
- 縦スクロールで月内全日表示、**並び順は古い→新しい（上→下）**
- 起動時に `ScrollViewReader` で **今日（または月最終日）にオートスクロール**
- 月ナビゲーション（◀ 2026年5月 ▶）で月を切り替え

### 4.2.1 セル描画ルール（部分時間の扱い）

「any-overlap」ルール: ある時間セル `[H:00, H:59]` が `SleepSession` の任意の区間（布団 or 睡眠）と1秒でも重なれば、そのセルの該当層を塗る。

例: `bedInAt = 23:30` の場合、23 時セルの下半分は赤で塗られる（30分しか布団にいなくても）。
分単位の精度が必要な場合は日編集画面で 4 時刻ピッカーから直接編集できる。

### 4.2.2 備考欄の日付アンカリング

`ChartCellCalculator.notes(forDay:sessions:)` が同日の備考を返す。**起床日（`bedOutAt` の暦日）にアンカー** することで、夜跨ぎセッション（5/3 23:00 入床 → 5/4 7:00 起床）の備考が両日に重複表示されない。`bedOutAt` が無い進行中セッションは `bedInAt` の暦日にフォールバック。同日に複数セッションがあれば `" / "` 区切りで結合。

### 4.3 入力モデル — Approach A: 2タップ + 朝の補正

1. **夜**: 「🌙 おやすみ」ボタンを 1 回タップ → `bedInAt = now` を記録
2. **朝**: 「☀️ おはよう」ボタンを 1 回タップ → `bedOutAt = now` を記録 → 補正シートが自動表示
3. **補正シート**:
   - 入床（bedInAt）と起床（bedOutAt）の **DatePicker（日付＋時刻）** — タップ時刻を後から修正可能
   - 「入眠時刻」スライダー（5分刻み、デフォルト = `bedInAt + 30分`、bed 範囲にクランプ）
   - 「覚醒時刻」スライダー（5分刻み、デフォルト = `bedOutAt - 15分`、bed 範囲にクランプ）
   - 備考テキスト
   - **時刻順序バリデーション** (`SleepRecordValidator`): `bedIn < bedOut`、`bedIn ≤ asleep ≤ awake ≤ bedOut` を満たさない場合は **保存ボタン無効化** ＋ 赤いインラインエラー表示
   - 「確定」で 4 時刻と `notes` を保存

### 4.4 「忘れた」検出

- **予防**: 就寝時刻リマインダーを毎日 push（デフォルト 22:30、設定で変更可）
- **検出**: 「おはよう」タップ時に進行中セッションが無ければモーダル表示「昨夜の入床時刻は？」（デフォルト = 前日 23:00）

## 5. データモデル

```swift
import SwiftData
import Foundation

@Model
final class SleepSession {
    // CloudKit 制約: 全 non-optional 属性に property-level デフォルトが必須、
    // かつ .unique 制約は使えない（詳細は §10.1）
    var id: UUID = UUID()
    var bedInAt: Date = Date.distantPast
    var bedOutAt: Date?
    var asleepAt: Date?
    var awakeAt: Date?
    var notes: String = ""
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(
        id: UUID = UUID(),
        bedInAt: Date,
        bedOutAt: Date? = nil,
        asleepAt: Date? = nil,
        awakeAt: Date? = nil,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) { /* ... */ }

    var isInProgress: Bool { bedOutAt == nil }
    var isFullyRecorded: Bool { bedOutAt != nil && asleepAt != nil && awakeAt != nil }
}
```

**重要**: `init()` のパラメータデフォルトは Swift の通常デフォルトだが、CloudKit がチェックするのは **プロパティ宣言レベル** のデフォルトのみ。`var x: Int` だけで `init` 側に default を置いても CloudKit は弾く。`var x: Int = 0` のように宣言側に書く必要がある。

### 5.1 状態マシン

```
[empty] / [completed]
   │
   │ tap "おやすみ"  →  create SleepSession(bedInAt: now)
   ▼
[in-bed]
   │
   │ tap "おはよう"  →  set bedOutAt = now, present correction sheet
   ▼
[correction-pending]
   │
   │ confirm sheet  →  set asleepAt, awakeAt, notes
   ▼
[completed]
```

「進行中」かどうかは `bedOutAt == nil` で判定。

### 5.2 1日 = 何セッション？

- v1: 主夜間睡眠 1 セッションを想定
- 昼寝など追加セッション: スコープ外（ただしモデルは複数セッション許容）
- 重複セッション登録時は確認ダイアログ → 後勝ち

## 6. アーキテクチャ

### 6.1 モジュール構成

| 層 | 責務 |
|---|---|
| Models | SwiftData モデル |
| Services | ビジネスロジック（チャート計算、PDF生成、通知、状態遷移） |
| Views | SwiftUI ビュー（feature 別に分割） |
| Utilities | 日付・フォーマット ヘルパー |
| Tests | XCTest ユニット／統合テスト |

### 6.2 主要サービス

- **DataStore** — SwiftData `ModelContainer` を CloudKit Private DB と一緒に構成。`FileManager.ubiquityIdentityToken` を確認してから CloudKit を有効化（§10）。CloudKit 失敗時はローカル SQLite、それも失敗したら最終手段で in-memory にフォールバック。Cloud と Local は別名のストアファイル（"Cloud.store" / "Local.store"）を使い、片方の失敗が他方を巻き込まないようにする。
- **ChartCellCalculator** — `[SleepSession]` を「日付 → 24セル状態配列」に投影。`notes(forDay:sessions:)` で同日の備考も返す。`Range<Date>` が trap しないよう `bedInAt < bedEnd` と `asleepAt < awakeAt` を守備的にチェック。
- **SleepStateMachine** — `[empty]` / `[in-bed]` / `[correction-pending]` / `[completed]` の遷移を判定
- **BackfillDetector** — 「おはよう」タップ時の forgot-tap 検出
- **SleepRecordValidator** — 時刻順序の不変条件 (`bedIn < bedOut`、`bedIn ≤ asleep ≤ awake ≤ bedOut`) を検証。`Issue` enum と日本語ローカライズメッセージを返す純粋関数。`DayEditSheet` と `MorningCorrectionSheet` の保存ボタン無効化に使う。
- **NotificationScheduler** — 就寝時刻リマインダーの登録・解除
- **PDFExporter** — 期間内のセッションを A4 縦 PDF にレンダリング。`pages(totalDays:)` は `nonisolated` （ユニットテストが MainActor 不要で呼べるように）。

## 7. UI 設計

### 7.1 ナビゲーション

```
TabView
├ 🏠 Home       (NavigationStack)
│  └ ⚙️ Settings (sheet from gear icon)
└ 📊 Chart      (NavigationStack)
   ├ 📝 DayEdit  (sheet on day-row tap)
   └ 📄 PDF      (push from toolbar button)

Modal:
└ 🌅 MorningCorrectionSheet (auto-present from Home when state = [correction-pending])
```

### 7.2 画面一覧

| # | 画面 | 主な要素 |
|---|---|---|
| 1 | HomeView | 円形大ボタン（状態で「おやすみ」or「おはよう」自動切替）／日付・時刻表示／右上歯車 |
| 2 | MorningCorrectionSheet | **入床/起床 DatePicker**（編集可能）／入眠スライダー／覚醒スライダー／備考／バリデーションエラー表示／確定ボタン |
| 3 | ChartView | 月ナビ（◀ 月 ▶）／PDF出力ボタン／2段ヘッダー（午前・午後・備考欄バナー / 0-11・0-11 時刻数字）／日次行スクロールリスト（古→新、起動時に今日へオートスクロール） |
| 4 | DayEditSheet | 4 時刻ピッカー（布団IN/入眠/覚醒/布団OUT）／備考／バリデーションエラー表示／保存・削除 |
| 5 | PDFExportView | 期間ピッカー（デフォルト直近1ヶ月）／プレビュー／ShareLink・印刷 |
| 6 | SettingsView | 就寝リマインダー時刻／通知 ON/OFF／iCloud 同期状態表示 |

### 7.3 ホーム画面の状態別表示

| State | ボタン | サブ表示 |
|---|---|---|
| empty / completed | 🌙 おやすみ | 「タップで入床時刻を記録」 |
| in-bed | ☀️ おはよう | 「就寝中: 23:14〜」 |
| correction-pending | (補正シート自動表示) | ボタン右上に赤丸バッジ |

## 8. PDF 出力仕様

- **デフォルト期間**: 今日から 1 ヶ月前 〜 今日（ユーザが期間ピッカーで変更可）
- **ページサイズ**: A4 縦 (210 × 297 mm)
- **構成**:
  1. ヘッダー: 「睡眠リズム表」 + 期間表示 + ページ番号
  2. 2段ヘッダー（午前/午後/備考欄バナー、0-11/0-11 時刻数字）
  3. 日付行（最大 35 日/ページ）— 各行は `[日付ラベル][24セル][備考カラム]`
- **複数ページ対応**: 期間が 35 日を超える場合は自動的にページ分割。**備考は各日の行内**に表示するので別ページは不要。
- **備考欄の枠線**: 各行の備考セルは時間セルと同じ `0.3 pt` 枠線で囲む（外周一括ではなく行ごと）。空セルも枠線を残す。
- **共有**: SwiftUI `ShareLink` で AirDrop / メール / ファイル保存
- **印刷**: `UIPrintInteractionController` ラッパー
- **寸法**: cellWidth=16pt、cellHeight=16pt、labelWidth=48pt、notesColumnWidth=110pt（A4 縦に収まる設計）

## 9. 通知仕様

- **就寝リマインダー**:
  - 種類: 毎日繰り返しのローカル通知
  - 時刻: ユーザ設定（デフォルト 22:30）
  - 本文例: 「おやすみ前にタップを忘れずに 🌙」
  - タップ時: アプリを Home 画面で起動
- **権限**: 初回タップ時に許可リクエスト、拒否時は設定画面から再許可導線

## 10. iCloud 同期

- SwiftData `ModelConfiguration("Cloud", cloudKitDatabase: .private("iCloud.com.ryan.sleeprecord"))` で構成
- ユーザ作業ゼロ（iCloud アカウントが iPhone に設定済みなら自動）
- アカウント未設定時はローカルのみで動作（設定画面に「iCloud OFF」表示）
- 同期失敗時はバックグラウンドで自動リトライ、UI ブロックなし

### 10.1 SwiftData × CloudKit の制約（実装で発覚した必須要件）

CloudKit はスキーマに 3 つの強い制約を持ち、違反すると **初回起動時にクラッシュ** または **CloudKit フレームワーク内部で `brk #1` トラップ**（try/catch でも捕まらない）：

1. **`@Attribute(.unique)` 禁止** — CloudKit は unique 制約をサポートしない。`SwiftData` の `persistentModelID` が暗黙の一意性を提供する。
2. **全 non-optional 属性にプロパティレベルのデフォルト必須** — `init` 側のデフォルトでは不可（§5 参照）。
3. **CloudKit 試行前に iCloud アカウントの存在をチェック** — `FileManager.default.ubiquityIdentityToken` が `nil` の場合 `cloudKitDatabase: .private(...)` を指定すると `NSCloudKitMirroringDelegate` が `EXC_BREAKPOINT` で死ぬ。`DataStore` は token 確認 → CloudKit / Local / In-memory の 3 段フォールバックで対応。

## 11. エッジケース

| ケース | 扱い |
|---|---|
| 12 時間以上の睡眠 | チャートで複数日にまたがって描画（自然な見た目） |
| 補正シートをキャンセル | bedInAt/bedOutAt は保持、asleepAt/awakeAt は nil で保存 |
| 既存セッションと重複登録 | 確認ダイアログ → ユーザ判断で上書き or キャンセル |
| 初回起動（データ無し） | チャートに「ホームから記録を始めましょう」プレースホルダ |
| iCloud アカウント未設定 | ローカル動作。設定画面で状態表示 |
| 通知許可拒否 | 設定画面で OFF 表示、再許可導線あり |
| タイムゾーン変更 | 全時刻は UTC 保存、表示時にデバイス TZ で変換 |
| 時刻順序の逆転（asleep > awake 等） | `SleepRecordValidator` が検出 → 保存ボタン無効化 + 赤エラー |
| 連続タップで bedIn == bedOut | 朝の補正シート初期化時に値クランプ ＋ Picker 制約から `in:` 削除（§11.1 参照） |
| 未来日付セッションを過去日描画 | `ChartCellCalculator` が `bedInAt >= dayEnd` セッションをスキップ |
| 進行中セッション（bedOutAt nil）の備考 | bedInAt の暦日にアンカー（フォールバック） |

### 11.1 SwiftUI の `Range`/`ClosedRange` 罠

Swift の `..<` と `...` は `lower > upper` で `Fatal error: Range requires lowerBound <= upperBound` を投げる。SwiftUI の DatePicker `in: lower...upper` も同じ。回避策：

- `ChartCellCalculator` で `Range<Date>` 構築前にガード
- `MorningCorrectionSheet` の DatePicker から `in:` 制約を削除し、代わりに `SleepRecordValidator` で保存時に弾く（中間状態が一時的に不整合でもクラッシュしない）
- init での @State 初期化時に `min`/`max` で範囲内クランプ

## 12. テスト戦略

### 12.1 ユニットテスト（v1 実装済 39 ケース）

| Suite | ケース数 | カバー内容 |
|---|---:|---|
| `ChartCellCalculatorTests` | 13 | 24セル投影（通常 / 日跨ぎ / 24h超 / 重複 / 部分時間 / 未来日付セッション / 逆転 sleep range / no-crash 系）+ 備考集約（5 ケース） |
| `SleepStateMachineTests` | 4 | 全状態遷移 (`empty`/`inBed`/`correctionPending`/`completed`) |
| `BackfillDetectorTests` | 2 | アクティブセッションあり/なし、デフォルト bedInAt 提案 |
| `PDFLayoutBuilderTests` | 5 | ページ分割境界（30/35/36/71/0 日） |
| `SleepRecordValidatorTests` | 15 | 全 4 不変条件 + バグ報告再現ケース + sleepOnly バリアント + 日本語メッセージ |
| **合計** | **39** | 全 PASS（ローカル実行で 0.05s） |

### 12.2 スコープ外（v1）
- 統合テスト（SwiftData CRUD、UNUserNotificationCenter モック）— Services の境界が明確で、現状ユニットだけで充分カバー
- UI snapshot テスト
- E2E テスト

## 13. ファイル構成

```
SleepRecord/
├ SleepRecordApp.swift          // @main エントリ + TabView root
├ Info.plist
├ SleepRecord.entitlements      // iCloud / push 通知
├ Models/
│  └ SleepSession.swift
├ Services/
│  ├ DataStore.swift             // SwiftData + CloudKit (token check + 3段フォールバック)
│  ├ ChartCellCalculator.swift   // セル投影 + 備考集約
│  ├ SleepStateMachine.swift
│  ├ BackfillDetector.swift
│  ├ SleepRecordValidator.swift  // 時刻順序検証（DayEdit / MorningCorrection 共通）
│  ├ NotificationScheduler.swift
│  └ PDFExporter.swift           // PDFKit、午前/午後 + 備考欄カラム
├ Views/
│  ├ Home/
│  │  ├ HomeView.swift
│  │  └ MorningCorrectionSheet.swift  // 4時刻すべて編集可、Validator 連携
│  ├ Chart/
│  │  ├ ChartView.swift           // 2段ヘッダー、古→新スクロール
│  │  ├ DayRowView.swift          // 日付・チャート・備考カラム
│  │  └ DayEditSheet.swift
│  ├ PDF/
│  │  ├ PDFExportView.swift
│  │  └ PDFPreviewView.swift
│  └ Settings/
│     └ SettingsView.swift
├ Utilities/
│  ├ DateRange.swift
│  └ TimeFormatter.swift
└ Tests/
   └ SleepRecordTests/
      ├ ChartCellCalculatorTests.swift
      ├ SleepStateMachineTests.swift
      ├ BackfillDetectorTests.swift
      ├ SleepRecordValidatorTests.swift
      └ PDFLayoutBuilderTests.swift

project.yml                     // xcodegen 設定（SleepRecord.xcodeproj を生成）
```

## 14. オープンクエスチョン

### v1 実装で確定したもの
- CloudKit Container ID: `iCloud.com.ryan.sleeprecord`（Apple Developer 登録は実機ビルド時に対応）
- 通知本文: 「そろそろお休みの時間です / おやすみ前にタップを忘れずに 🌙」
- カラーパレット: ホーム背景 = 紫グラデーション（夜）/ 黄色（朝）、布団 = `#E63946`（赤）、睡眠 = 黒斜線

### 残課題（v2 候補）
- アプリアイコンの正式デザイン（現在は Xcode デフォルト）
- App Store 配信の有無
- iCloud 同期の競合解消ロジック（同時編集が起きた場合の挙動）— SwiftData が暗黙に持つが詳細未確認
- iOS 26 Liquid Glass の採用（`.glassEffect` / `GlassEffectContainer`）
- 昼寝（複数セッション/日）の本格 UX サポート
- 睡眠統計（睡眠効率、平均総睡眠時間）

## 15. 変更履歴

- **2026-05-04 (初版)**: 5 セクション設計、Approach A 確定、5 画面構成
- **2026-05-04 (実装中)**: iOS deployment target を 17.0 → 26.4 に変更
- **2026-05-04 (実装後)**:
  - SwiftData CloudKit 制約を §5 / §10.1 に追記（`@Attribute(.unique)` 禁止、property defaults 必須、ubiquityIdentityToken チェック）
  - `SleepRecordValidator` を §6.2 に追加（時刻順序の不変条件）
  - `MorningCorrectionSheet` の入床/起床も編集可能に（§4.3 / §7.2）
  - `Range<Date>` 罠の対策を §11.1 に追記
  - チャート形式を伝統的な紙のリズム表に合わせて再設計（§4.2）: 午前/午後 バナー、0-11/0-11 時刻、備考欄を独立カラム化
  - 並び順を古→新（上→下）に変更、起動時オートスクロール
  - PDF も同様に再設計（§8）: 備考は各行に併記（旧仕様の末尾「備考一覧」ページは削除）
  - テスト 16 → 39 ケースに拡充（§12.1）
- **2026-05-04 (v1.1 微調整)**:
  - 備考欄の各日セルに枠線を追加（§4.2 / §8）。時間セルと同じ枠線（画面: 0.4 / PDF: 0.3 pt）で囲み、空セルも枠線を残すことで 24 時間セル＋備考欄が一体の表組みとして見えるように修正。実装前は備考欄が文字のみ（画面）・外周のみ（PDF）で各日のグリッドセルに対応する区切りが無かった。

