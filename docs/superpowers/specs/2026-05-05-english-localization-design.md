# SleepRecord English Localization — 設計書

- **Date**: 2026-05-05
- **Status**: 設計確定（実装未着手）
- **Owner**: Ryan
- **Plan**: `docs/superpowers/plans/2026-05-05-english-localization.md` (to be written)
- **Last updated**: 2026-05-05 — 初版

## 1. 概要

SleepRecord アプリに **英語ローカライズ** を追加する。親 spec（`2026-05-04-sleep-rhythm-chart-design.md`）§2 で「多言語対応（日本語のみ）」が v1 の non-goal として明示されていた。本 spec はそれを v1.x で巻き返す。

同時に、ユーザがアプリ内で言語を切り替えられるよう **設定画面に言語 Picker を追加** する（システム / 日本語 / English）。

**プライマリ・ユースケース**:
1. 英語環境の iOS デバイスで SleepRecord を起動すると、UI が英語で表示される
2. 日本語ユーザが一時的に英語で使いたい場合は、設定画面から英語を選択できる（再起動が必要）

## 2. ゴールと非ゴール

### Goals (v1.2)
- すべてのユーザ可視文字列を ja / en の 2 言語で提供
- iOS 17+ の **String Catalog** (`*.xcstrings`) を採用し、単一ファイルで両言語を管理
- 設定画面に **言語 Picker**（System / 日本語 / English）を追加
- ホーム画面のアプリ名 (`CFBundleDisplayName`) も両言語で出る（ja: 睡眠リズム / en: Sleep Rhythm）

### Non-goals (v1.2)
- 第三言語（中国語、韓国語など）— 必要になったら別 spec
- 右から左に書く言語（RTL）— 対応言語が ja/en のみなのでレイアウト変更不要
- 複数形（plurals）/ stringsdict — 現状のコピーに数依存の可変箇所が無い
- ネイティブスピーカーによる翻訳監修 — まずは実装者の最善努力翻訳でリリース、ユーザは `.xcstrings` を直接編集して微調整できる
- 言語のライブ切り替え（再起動なし）— iOS 標準の restart-based パターンを採用（§4.3）

## 3. ローカライズの仕組み

### 3.1 採用する仕組み: String Catalog

iOS 17 から導入された **String Catalog**（`.xcstrings` 拡張子）を採用する。1 つの JSON ファイルに全言語の翻訳を保持し、Xcode が自動でソースから文字列を抽出してくれる。

選定理由:
- 単一ファイル管理（古い `Localizable.strings` は言語ごとに別ファイル）
- ソースからの自動抽出（`Text("foo")` を書けば自動的に xcstrings の翻訳対象に）
- 型安全な API: SwiftUI 側は `Text("foo")` のまま、Swift 側は `String(localized: "foo")`
- iOS 17+ 限定だが、本プロジェクトの min iOS は 26.4 なので互換性問題なし

却下した代替: legacy `Localizable.strings + Localizable.stringsdict`。互換性以外の利点なし。

### 3.2 ファイル構成

```
SleepRecord/
├── Localizable.xcstrings           ← 新規。アプリ全体の UI 文字列
└── InfoPlist.xcstrings             ← 新規。Info.plist の CFBundleDisplayName 専用
```

`InfoPlist.xcstrings` を `Localizable.xcstrings` と分けるのは Apple の標準慣例（Info.plist 系のキーは `InfoPlist` という別名前空間）。

### 3.3 SwiftUI 側の呼び出し

既存コードは既に `Text("ホーム")`, `Label("入床", systemImage: ...)`, `Section("備考")` のように **裸の文字列リテラル** を渡している。これらは SwiftUI が自動的に `LocalizedStringKey` として扱い、`Localizable.xcstrings` を引きに行く。**ソースコード側のコール箇所変更は不要**。

例外: 文字列補間を含む `Text("就寝中: \(time, format: .dateTime...) 〜")` は補間の入った `LocalizedStringKey` として扱われ、xcstrings 側で `"就寝中: %@ 〜"` のような placeholder 形式で翻訳される。これも自動で動作する。

### 3.4 SwiftUI 外の呼び出し

`SleepRecordValidator` / `NotificationScheduler` / `PDFExporter` は SwiftUI ではなく純粋 Swift。これらは `String(localized: "key", defaultValue: "デフォルト日本語")` を使う。

例:
```swift
// SleepRecordValidator.swift
case .bedInAfterBedOut:
    return String(
        localized: "validator.bedInAfterBedOut",
        defaultValue: "入床時刻は起床時刻より前である必要があります"
    )
```

`defaultValue` を明示するのは、xcstrings に未登録の状態でもビルドが通り、かつデフォルトが「development language = ja」の文字列になるようにするため。

## 4. 言語設定 UI

### 4.1 設定画面に新セクション

`SettingsView.swift` に以下のセクションを追加:

```swift
Section("言語 / Language") {
    Picker("言語 / Language", selection: $languagePref.selected) {
        Text("System (システム)").tag(LanguageOption.system)
        Text("日本語").tag(LanguageOption.japanese)
        Text("English").tag(LanguageOption.english)
    }
    .onChange(of: languagePref.selected) { _, _ in
        showRestartAlert = true
    }
}
.alert("再起動が必要 / Restart Required", isPresented: $showRestartAlert) {
    Button("OK") { }
} message: {
    Text("言語を変更するにはアプリを再起動してください\nRestart the app to apply the language change")
}
```

セクションヘッダーが意図的にバイリンガル（「言語 / Language」）なのは、設定変更の途中で UI 言語が切り替わる遷移を考えてのこと。

### 4.2 永続化と読み出し

新サービス `LanguagePreference.swift` を作る:

```swift
import Foundation

enum LanguageOption: String, CaseIterable, Identifiable {
    case system = ""
    case japanese = "ja"
    case english = "en"
    var id: String { rawValue }
}

@Observable
final class LanguagePreference {
    static let shared = LanguagePreference()
    static let appleLanguagesKey = "AppleLanguages"
    static let userPrefKey = "appLanguage"

    var selected: LanguageOption {
        didSet { apply() }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.userPrefKey) ?? ""
        self.selected = LanguageOption(rawValue: raw) ?? .system
    }

    private func apply() {
        UserDefaults.standard.set(selected.rawValue, forKey: Self.userPrefKey)
        switch selected {
        case .system:
            UserDefaults.standard.removeObject(forKey: Self.appleLanguagesKey)
        case .japanese, .english:
            UserDefaults.standard.set([selected.rawValue], forKey: Self.appleLanguagesKey)
        }
    }
}
```

iOS は **アプリ起動時** に `UserDefaults.standard.array(forKey: "AppleLanguages")` を読み、それがあれば `Bundle.main` の言語選択をオーバーライドする。アプリ側で他に何もしなくても次回起動から反映される。

### 4.3 なぜ restart 必須か

SwiftUI の `Text("foo")` は **レンダリング時に** `Bundle.main.localizedString(forKey: "foo", value: nil, table: nil)` を呼ぶ。`Bundle.main` の有効ロケールはアプリ起動時に固定される。動的に切り替えるには `Bundle` の swizzling または `.environment(\.locale, ...)` 経由でカスタム Bundle を持ち回す必要があり、シングルユーザのこの規模のアプリには過剰設計。

iOS 純正アプリ（Notes、Mail など）も同じ restart-based パターン。

### 4.4 CloudKit との関係

`AppleLanguages` UserDefaults は **意図的に CloudKit と同期しない**。各デバイスで独立。

例: iPhone を English にしても、iPad は別の選択ができる。これは iOS の標準挙動と整合的（システム設定の言語もデバイスごとに独立）。SwiftData の `SleepSession` は引き続き CloudKit で同期されるので、データは共通、UI 言語はデバイスごとという正しい分離。

## 5. 翻訳対象文字列

### 5.1 概数

ユーザ可視文字列: **約 55 キー**。内訳:

| ソースファイル | キー数 | 例 |
|---|---:|---|
| `HomeView.swift` + `BackfillSheet` | 14 | おやすみ → Good night, おはよう → Good morning, 補正する → Adjust, 就寝中 → In bed since, 入床時刻 → Bedtime |
| `MorningCorrectionSheet.swift` | 10 | 入床/起床/入眠/覚醒 → Bedtime/Wake-up/Asleep/Awake, 確定 → Save, 後で → Later |
| `ChartView.swift` + `DayRowView.swift` | 5 | チャート → Chart, 午前 → AM, 午後 → PM, 備考欄 → Notes |
| `DayEditSheet.swift` | 6 | 時刻 → Times, 備考 → Notes, 保存 → Save, キャンセル → Cancel, この日の記録を削除 → Delete this day |
| `SettingsView.swift` | 12 | 設定 → Settings, 就寝時刻リマインダー → Bedtime reminder, iCloud 同期 → iCloud sync, 言語 / Language（言語セクション含む 4 キー） |
| `PDFExportView.swift` | 6 | PDF出力 → Export PDF, この期間でプレビュー → Preview, 共有 / 保存 → Share/Save, 印刷 → Print |
| `PDFExporter.swift`（描画文字列） | 5 | 睡眠リズム表 → Sleep Rhythm Chart, 期間 → Period, 備考欄 → Notes, 午前 → AM, 午後 → PM |
| `SleepRecordValidator.swift` | 4 | bedIn ≥ bedOut 等の 4 種類のエラーメッセージ |
| `NotificationScheduler.swift` | 2 | "そろそろお休みの時間です" → "Time to wind down", "おやすみ前にタップを忘れずに 🌙" → "Don't forget to tap before bed 🌙" |
| `InfoPlist.xcstrings` (display name) | 1 | 睡眠リズム → Sleep Rhythm |
| **合計** | **約 65** | |

### 5.2 翻訳済まない文字列

- `HomeView.swift:35` の `Text("SLEEP RHYTHM")` — 既に英語、両言語で同じ表示で OK（変更不要）
- 24 時間ラベル `0..23`、月ヘッダ `2026年5月` 等の数値 — locale-neutral / SwiftUI の format style が自動でロケール対応

### 5.3 翻訳の品質

実装者の最善努力翻訳。`.xcstrings` は人間可読 JSON なので、ユーザが直接 Xcode の Catalog エディタや任意のテキストエディタで編集して語感を整えられる。

## 6. ロケール対応の挙動

### 6.1 日付フォーマット

SwiftUI の `Text(date, format: .dateTime.year().month().day().weekday())` は **デバイスロケール** で自動レンダリング。コード変更不要で、JP デバイスでは `2026年5月4日(月)` 、EN デバイスでは `May 4, 2026 (Mon)` と出る。

### 6.2 PDF 内の日付

現状 `PDFExporter.swift:157-158`:
```swift
formatter.locale = Locale(identifier: "ja_JP")
formatter.dateFormat = "M/d (E)"
```

これは「日本語ハードコード」なので EN ユーザでも `5/4 (月)` と出てしまう。修正:

```swift
formatter.locale = .current
formatter.dateFormat = "M/d (E)"
```

`.current` は `AppleLanguages` オーバーライドも反映する（`Bundle.main` 経由）。EN は `5/4 (Mon)`、JP は `5/4 (月)`。

### 6.3 ユーザの設定で言語を変えた場合

`AppleLanguages` UserDefaults をセットすると、再起動後 `Locale.current` も `Bundle.main.preferredLocalizations.first` も新しい言語に追従する。日付フォーマット、validator メッセージ、SwiftUI Text、すべてが整合的に切り替わる。

## 7. Info.plist / project.yml の変更

### 7.1 Info.plist

追加:
```xml
<key>CFBundleLocalizations</key>
<array>
  <string>ja</string>
  <string>en</string>
</array>
```

`CFBundleDevelopmentRegion = ja` は据え置き（`ja` でも `en` でもないロケールは ja にフォールバックする — シングルユーザアプリとして妥当）。

`CFBundleDisplayName = 睡眠リズム` のハードコードは削除し、`InfoPlist.xcstrings` で:
```
"CFBundleDisplayName" = {
  "ja" : "睡眠リズム",
  "en" : "Sleep Rhythm"
}
```

### 7.2 project.yml

`developmentLanguage: ja` 据え置き。

`*.xcstrings` ファイルは `sources: [{path: SleepRecord}]` の再帰検索で自動的に拾われる（xcodegen のデフォルト挙動）。明示的な追加設定は不要。

## 8. テスト戦略

### 8.1 新規ユニットテスト

新規 suite **`LanguagePreferenceTests`** （3 ケース）:

1. `selected = .english` → `UserDefaults.AppleLanguages == ["en"]` かつ `userPrefKey == "en"`
2. `selected = .japanese` → `UserDefaults.AppleLanguages == ["ja"]` かつ `userPrefKey == "ja"`
3. `selected = .system` → `UserDefaults.AppleLanguages` が削除され、`userPrefKey == ""`

新規 suite **`LocalizationCoverageTests`** （4 ケース）:

各 validator のエラーメッセージキーに対して、`String(localized: key, locale: Locale(identifier: "en"))` が空文字列でなく、かつ `defaultValue` と異なる（つまり実際に英訳が登録されている）ことを検証。これにより xcstrings に翻訳の登録漏れが起きるとビルドではなくテストで早期検出できる。

合計 **+7 ケース**。既存 39 + 7 = **46 ケース**。

### 8.2 視覚スモーク

iPhone 17e iOS 26.4 シミュレータで:

1. デバイス言語が `ja-JP` のまま起動 → すべての画面が日本語のまま（regression なし）
2. 設定画面 → 言語を English に変更 → 再起動アラート → 再起動 → ホーム/チャート/設定/PDF が英語表記
3. アプリ名がホーム画面で「Sleep Rhythm」に切り替わる
4. 設定画面 → 言語を System に戻す → 再起動 → デバイスロケール（ja-JP）で日本語に戻る

### 8.3 既存テストへの影響

39 ケースのうち、`SleepRecordValidatorTests` (15) は日本語メッセージ文字列を直接アサートしているケースが含まれる可能性。`String(localized:)` 化に伴いテストの更新が必要かもしれない（テストロケールを ja に固定して既存メッセージを保つ／キーで比較する等）。Plan で具体的な対処を明記する。

## 9. エッジケース

| ケース | 扱い |
|---|---|
| 既存のユーザが iOS デバイスを EN ロケールで使っていた | 現状: ja にフォールバック表示。新仕様: en で表示。アップグレード後の挙動変化を許容（むしろ改善） |
| ユーザが Settings で English を選んだあとアプリを kill せず使い続ける | UI は ja のまま。restart アラートで明示的に通知する |
| `AppleLanguages` を手動で複数言語の配列にセット | 先頭が ja でも en でもなければ ja にフォールバック（CFBundleDevelopmentRegion 経由） |
| iCloud アカウント未設定 | データ層と無関係なので影響なし |
| validator のテストで日本語アサーションを使っている | Plan のタスクで `Locale(identifier: "ja")` を渡す形に変更 |

## 10. ファイル構成（差分）

```
SleepRecord/                                          (既存)
├── Localizable.xcstrings                             ← 新規
├── InfoPlist.xcstrings                               ← 新規
├── Info.plist                                        ← CFBundleLocalizations 追加、CFBundleDisplayName 削除
├── Services/
│   └── LanguagePreference.swift                      ← 新規
├── Services/SleepRecordValidator.swift               ← String(localized:) 化
├── Services/NotificationScheduler.swift              ← String(localized:) 化
├── Services/PDFExporter.swift                        ← Locale.current + String(localized:) 化
└── Views/Settings/SettingsView.swift                 ← 言語 Picker セクション追加

SleepRecordTests/                                     (既存)
├── LanguagePreferenceTests.swift                     ← 新規
├── LocalizationCoverageTests.swift                   ← 新規
└── SleepRecordValidatorTests.swift                   ← Locale 固定化

docs/superpowers/
├── specs/
│   └── 2026-05-05-english-localization-design.md     ← 本ファイル
└── plans/
    └── 2026-05-05-english-localization.md            ← 後で追加
```

`project.yml` 変更なし。`xcodegen generate` を `.xcstrings` 追加後に 1 回実行する。

## 11. 参照

- 親 spec: `docs/superpowers/specs/2026-05-04-sleep-rhythm-chart-design.md` §2 non-goals「多言語対応（日本語のみ）」
- アイコン spec: `docs/superpowers/specs/2026-05-05-app-icon-design.md`（display name はアイコンとは独立）
- Apple String Catalog 公式: WWDC23「Discover String Catalogs」
- iOS Settings → Per-App Language: https://developer.apple.com/documentation/xcode/adding-support-for-languages-and-regions

## 12. 変更履歴

- **2026-05-05 (初版)**: String Catalog 採用、設定画面に言語 Picker、restart-based 切り替え方式で確定
