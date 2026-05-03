# 睡眠リズム表 iOS App — 設計書

- **Date**: 2026-05-04
- **Status**: Draft (ユーザレビュー待ち)
- **Owner**: Ryan

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
| Min iOS | 17.0 |
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

- 1日 = 1行 = 24セル（1セル = 1時間）
- AM (0-12時) と PM (12-24時) は同一行、12時境界に太線
- 日付ラベルを左に配置
- 縦スクロールで複数日表示、新しい日が上
- 月ナビゲーション（◀ 2026年5月 ▶）で月を切り替え

### 4.2.1 セル描画ルール（部分時間の扱い）

「any-overlap」ルール: ある時間セル `[H:00, H:59]` が `SleepSession` の任意の区間（布団 or 睡眠）と1秒でも重なれば、そのセルの該当層を塗る。

例: `bedInAt = 23:30` の場合、23 時セルの下半分は赤で塗られる（30分しか布団にいなくても）。
分単位の精度が必要な場合は日編集画面で 4 時刻ピッカーから直接編集できる。

### 4.3 入力モデル — Approach A: 2タップ + 朝の補正

1. **夜**: 「🌙 おやすみ」ボタンを 1 回タップ → `bedInAt = now` を記録
2. **朝**: 「☀️ おはよう」ボタンを 1 回タップ → `bedOutAt = now` を記録 → 補正シートが自動表示
3. **補正シート**:
   - 「入眠時刻」スライダー（5分刻み、デフォルト = `bedInAt + 30分`）
   - 「覚醒時刻」スライダー（5分刻み、デフォルト = `bedOutAt - 15分`）
   - 備考テキスト
   - 「確定」で `asleepAt`, `awakeAt`, `notes` を保存

### 4.4 「忘れた」検出

- **予防**: 就寝時刻リマインダーを毎日 push（デフォルト 22:30、設定で変更可）
- **検出**: 「おはよう」タップ時に進行中セッションが無ければモーダル表示「昨夜の入床時刻は？」（デフォルト = 前日 23:00）

## 5. データモデル

```swift
import SwiftData
import Foundation

@Model
final class SleepSession {
    @Attribute(.unique) var id: UUID
    var bedInAt: Date           // 「おやすみ」タップ or バックフィル
    var bedOutAt: Date?         // 「おはよう」タップ。nil = 進行中
    var asleepAt: Date?         // 入眠（補正シート or 編集）
    var awakeAt: Date?          // 覚醒（補正シート or 編集）
    var notes: String = ""
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), bedInAt: Date) {
        self.id = id
        self.bedInAt = bedInAt
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

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

- **DataStore** — SwiftData `ModelContainer` を CloudKit Private DB と一緒に構成
- **ChartCellCalculator** — `[SleepSession]` を「日付 → 24セル状態配列」に投影
- **SleepStateMachine** — `[empty]` / `[in-bed]` / `[correction-pending]` / `[completed]` の遷移を判定
- **BackfillDetector** — 「おはよう」タップ時の forgot-tap 検出
- **NotificationScheduler** — 就寝時刻リマインダーの登録・解除
- **PDFExporter** — 期間内のセッションを A4 縦 PDF にレンダリング

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
| 2 | MorningCorrectionSheet | 入眠スライダー／覚醒スライダー／備考／確定ボタン |
| 3 | ChartView | 月ナビ（◀ 月 ▶）／PDF出力ボタン／日次行のスクロールリスト |
| 4 | DayEditSheet | 4 時刻ピッカー（布団IN/入眠/覚醒/布団OUT）／備考／保存・削除 |
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
  1. ヘッダー: 「睡眠リズム表」 + 期間表示
  2. チャート（アプリ内と同じ表記、1ページ最大 35 日まで）
  3. 備考一覧（日付 + 備考テキスト）
- **複数ページ対応**: 期間が 35 日を超える場合は自動的にページ分割（チャート → 残り日チャート → 備考の順）
- **共有**: SwiftUI `ShareLink` で AirDrop / メール / ファイル保存
- **印刷**: `UIPrintInteractionController` ラッパー

## 9. 通知仕様

- **就寝リマインダー**:
  - 種類: 毎日繰り返しのローカル通知
  - 時刻: ユーザ設定（デフォルト 22:30）
  - 本文例: 「おやすみ前にタップを忘れずに 🌙」
  - タップ時: アプリを Home 画面で起動
- **権限**: 初回タップ時に許可リクエスト、拒否時は設定画面から再許可導線

## 10. iCloud 同期

- SwiftData `ModelConfiguration(cloudKitDatabase: .private(.init(containerIdentifier: ...)))` で構成
- ユーザ作業ゼロ（iCloud アカウントが iPhone に設定済みなら自動）
- アカウント未設定時はローカルのみで動作（設定画面に「iCloud OFF」表示）
- 同期失敗時はバックグラウンドで自動リトライ、UI ブロックなし

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

## 12. テスト戦略

### 12.1 必須ユニットテスト
- `ChartCellCalculatorTests` — 24セル投影ロジック（最重要・複雑）
  - 通常夜間睡眠 / 日跨ぎ / 24h超 / 重複 / 部分時間
- `SleepStateMachineTests` — 全状態遷移
- `BackfillDetectorTests` — forgot-tap 検出ロジック
- `PDFLayoutBuilderTests` — 期間データ収集とページ収まり判定

### 12.2 統合テスト
- SwiftData CRUD（in-memory `ModelContainer`）
- Notification scheduling（モック `UNUserNotificationCenter`）

### 12.3 スコープ外（v1）
- UI snapshot テスト
- E2E テスト

## 13. ファイル構成

```
SleepRecord/
├ SleepRecordApp.swift          // @main エントリ
├ Models/
│  └ SleepSession.swift
├ Services/
│  ├ DataStore.swift             // SwiftData + CloudKit
│  ├ ChartCellCalculator.swift
│  ├ SleepStateMachine.swift
│  ├ BackfillDetector.swift
│  ├ NotificationScheduler.swift
│  └ PDFExporter.swift
├ Views/
│  ├ Home/
│  │  ├ HomeView.swift
│  │  └ MorningCorrectionSheet.swift
│  ├ Chart/
│  │  ├ ChartView.swift
│  │  ├ DayRowView.swift
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
      └ PDFLayoutBuilderTests.swift
```

## 14. オープンクエスチョン（実装フェーズで決める）

- CloudKit Container ID の正式名（Apple Developer 登録後に決定）
- アプリアイコン・カラーパレット詳細
- 設定画面の細部（リマインダー本文カスタマイズの可否など）
- App Store 配信の有無（個人利用のみで配信しない可能性あり）

