# SleepRecord App Icon — 設計書

- **Date**: 2026-05-05
- **Status**: 設計確定（実装未着手）
- **Owner**: Ryan
- **Plan**: `docs/superpowers/plans/2026-05-05-app-icon.md` (to be written)
- **Last updated**: 2026-05-05 — 初版

## 1. 概要

SleepRecord アプリの正式アイコンを作成する。現在は `Assets.xcassets` 自体が存在せず、Xcode のデフォルトプレースホルダが使われている。spec 親文書の §14「残課題（v2 候補）」で「アプリアイコンの正式デザイン」が明示的に挙がっており、その対応。

**プライマリ・ユースケース**: ホーム画面・Spotlight・App Switcher で SleepRecord を識別できるアイコンを表示する。

**前提**: ストア配信の有無は未定（spec 親文書 §14）なので、本スコープは **デバイス上で正しく表示されるところまで**。App Store Connect 用のマーケティングアイコンや App Store screenshot 整備は対象外。

## 2. ゴールと非ゴール

### Goals (v1.2)
- 1 枚の 1024×1024 PNG を `Assets.xcassets/AppIcon.appiconset/` に配置し、ビルドしたアプリのホーム画面アイコンが置き換わる
- アイコンを **コードから再現可能** にする（外部画像生成サービスや手書きツールに依存しない）
- ブランドの夜空感を維持し、ホーム画面ヒーローボタン（紫グラデ + 🌙）と視覚的に同一スタックに見える

### Non-goals (v1.2)
- iOS 18+ の **Tinted icon** バリアント（モノクロ PNG を OS が自動着色）
- iOS 18+ の **Dark mode** 専用バリアント（夜空テーマなのでデフォルトのまま機能する想定）
- iOS 26 Liquid Glass 風の半透明レイヤー処理（親 spec §14 の v2 候補）
- App Store Marketing Icon、ストア用スクリーンショット
- マルチプラットフォーム（macOS/visionOS など）アイコン
- ローカライズされたアプリ名表示（多言語対応は別 spec）

## 3. ビジュアル仕様

### 3.1 キャンバス

- サイズ: **1024 × 1024 px**
- 透明度: **なし**（完全不透明 sRGB PNG）
- カラースペース: sRGB
- iOS 側で角丸（superellipse）が自動で適用されるので、本アイコン内では角丸を描かない

### 3.2 背景

- 上下 **垂直リニアグラデーション**
  - top（y=0）: `#0D0D2B` ≒ `Color(red: 0.05, green: 0.05, blue: 0.17)`
  - bottom（y=1024）: `#332666` ≒ `Color(red: 0.20, green: 0.15, blue: 0.40)`
- パレットの根拠: `SleepRecord/Views/Home/HomeView.swift:27-29` の non-inBed 状態の背景グラデと同一

### 3.3 三日月（フォーカル要素）

- **配置**: アイコン中央、わずかに上寄り（中心 y = 480、画像中心は 512、つまり 32 px 上）
- **サイズ**: 直径 **530 px**（アイコン辺の 51.7%）
- **色**: `#F5EFD8`（暖かみのあるクリーム色。実物の月の感じ。純白だと冷たい）
- **形状**: 「外円 − 内円」のパスで三日月を作る
  - 外円: 中心 `(512, 480)`, 半径 `265`
  - 内円（くりぬき）: 中心 `(512 + 110, 480)`, 半径 `230` ← 右に 110 px オフセット、y は揃える
  - これにより上下の三日月の先端が対称（約 35 px ずつ）、左側の太い背が約 145 px、開口部は右側
  - 偶奇規則（even-odd fill）で外円から内円を抜く
- **表面ディテール**: クレーターなどは描かない。フラットな塗りつぶしで小サイズ視認性を優先
- **発光**: 三日月の外周に半径 60 px のソフトな外側シャドウ。色 `#F5EFD8`、不透明度 0.18。Core Graphics の `setShadow(offset: .zero, blur: 60, color: ...)` で十分

### 3.4 星（補助要素）

5 点。座標 / 直径 / 不透明度（座標は左上原点、px）：

| # | x | y | diameter | opacity |
|---|---:|---:|---:|---:|
| 1 | 200 | 200 | 8 | 0.55 |
| 2 | 320 | 140 | 12 | 0.70 |
| 3 | 150 | 360 | 14 | 0.50 |
| 4 | 820 | 760 | 8 | 0.40 |
| 5 | 720 | 880 | 10 | 0.60 |

- 色: 純白 `#FFFFFF`
- 形状: ベタ塗りの円（star 形状にするとサイズ次第で潰れて読みにくいので円が安全）
- 三日月の影に星が重なる場合はそのまま描画（z-order: 背景 → 星 → 月 と重ねる。星は月の glow より下）

### 3.5 文字 / バッジ

**入れない**。テキストや小さな装飾を入れると 40×40 pt（Spotlight 最小サイズ）で潰れる。フォーカル要素は三日月の単一形状のみ。

## 4. アセットカタログ仕様

iOS 17 から **「Single Size」AppIcon** がサポートされ、1024×1024 PNG を 1 枚置けば OS が他のサイズを自動派生する。本 spec はこれを採用する。

### 4.1 ファイル構成

```
SleepRecord/Assets.xcassets/
├── Contents.json                          ← 空の info マーカー
└── AppIcon.appiconset/
    ├── Contents.json                      ← 1024×1024 単一エントリ
    └── icon-1024.png                      ← 生成された PNG
```

### 4.2 `Assets.xcassets/Contents.json`

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

### 4.3 `AppIcon.appiconset/Contents.json`

```json
{
  "images" : [
    {
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

`idiom: universal` + `platform: ios` で iPhone / iPad / Spotlight / Notification すべてに対応。

## 5. 生成スクリプト仕様

### 5.1 ファイル

- パス: `tools/generate-icon.swift`
- 言語: Swift（macOS の `swift` インタプリタで直接実行可能）
- 依存: macOS 標準の `CoreGraphics` / `ImageIO` / `UniformTypeIdentifiers` のみ
- ターゲット: 開発用ツール。アプリターゲットには含めない（`tools/` は xcodegen の sources パスから外れているので自動で除外される）

### 5.2 実行

```bash
swift tools/generate-icon.swift
```

引数なし。出力は固定パス `SleepRecord/Assets.xcassets/AppIcon.appiconset/icon-1024.png`。標準出力には進捗ログを出す（`Wrote 1024x1024 PNG to ...`）。

### 5.3 主要処理（疑似コード）

```swift
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

let size: CGFloat = 1024
let context = CGContext(...)  // 1024x1024, sRGB, no alpha

// 1) 背景グラデ
let gradient = CGGradient(colorsSpace: ..., colors: [topColor, bottomColor], locations: [0,1])
context.drawLinearGradient(gradient, start: (0,0), end: (0,1024), options: [])

// 2) 星（月より下）
for star in stars {
    context.setFillColor(.white * star.opacity)
    context.fillEllipse(in: CGRect(...))
}

// 3) 三日月の glow（影だけ先に描く）
context.setShadow(offset: .zero, blur: 60, color: creamWithAlpha(0.18))
context.beginTransparencyLayer(auxiliaryInfo: nil)
let outer = CGPath(ellipseIn: outerRect, transform: nil)
let inner = CGPath(ellipseIn: innerRect, transform: nil)
let crescent = CGMutablePath()
crescent.addPath(outer)
crescent.addPath(inner)
context.addPath(crescent)
context.setFillColor(creamColor)
context.fillPath(using: .evenOdd)  // 外円から内円を引く
context.endTransparencyLayer()

// 4) PNG 書き出し
let cgImage = context.makeImage()!
let dest = CGImageDestinationCreateWithURL(outputURL, UTType.png.identifier, 1, nil)
CGImageDestinationAddImage(dest, cgImage, nil)
CGImageDestinationFinalize(dest)
```

完全実装は Plan に書き出す（本 spec はインターフェース仕様まで）。

### 5.4 不変条件

- 同じスクリプトを実行すれば同じバイト列の PNG が出る（決定論的）。
- スクリプトは `Assets.xcassets/...` ディレクトリが存在しなくても作成しない（呼び出し側で `mkdir -p` してから実行する。Plan の手順に含める）。
- 失敗時は exit code ≠ 0 と stderr メッセージ。

## 6. ビルドとの統合

1. `swift tools/generate-icon.swift` で PNG を生成
2. PNG が `Assets.xcassets/AppIcon.appiconset/` に置かれる
3. `xcodegen generate` を実行して、新しい `Assets.xcassets` ディレクトリが Xcode プロジェクトの「Resources」フェーズに自動で含まれるようにする
4. `xcodebuild build` するとコンパイル時にアセットコンパイラ（`actool`）が PNG を `Assets.car` にバンドル
5. アプリをシミュレータで起動 → ホーム画面アイコン置換確認

`project.yml` の変更は不要。既存の `sources: - path: SleepRecord` は再帰的に `*.xcassets` を拾う。

## 7. テスト戦略

このアイコンは描画ロジックではなくアセットなので、ユニットテスト追加はしない。

| 検証 | 方法 |
|---|---|
| PNG が生成される | スクリプト実行後にファイルが存在し、1024×1024 PNG であること（`file icon-1024.png` または Read tool で確認） |
| アプリにバンドルされる | `xcodebuild build` 成功後、`SleepRecord.app/Assets.car` に AppIcon が含まれること（実質ビルドが通れば OK） |
| 視覚確認 | iPhone 17e iOS 26.4 シミュレータでアプリを起動し、ホーム画面 → Library に戻ってアイコンを目視確認 |
| 既存テスト回帰 | 39/39 が引き続き PASS（変更がアセットのみなので影響なし） |

UI snapshot テストは spec §12.2 で out of scope。同方針を踏襲。

## 8. エッジケース

| ケース | 扱い |
|---|---|
| `Assets.xcassets` がすでに存在する場合 | 新規作成 → スクリプトが上書きしないように、Plan の手順は `mkdir -p` のみ使用（`rm -rf` はしない） |
| `tools/` ディレクトリが存在しない場合 | Plan で `mkdir -p tools` を含める |
| Swift スクリプト実行が DEVELOPER_DIR を要求する場合 | macOS 標準の `swift` で動く（CoreGraphics は SDK 不要）。CLAUDE.md 互換のため `DEVELOPER_DIR=/Applications/Xcode.app/...` を Plan の手順に明記 |
| iCloud アカウント未設定での起動 | `DataStore` が in-memory フォールバックするので影響なし。アイコン表示はアプリ実行に依存しない |
| iOS 17 未満のデバイス | spec 親文書で min iOS 26.4 なので非対応 |

## 9. ファイル構成（差分）

```
SleepRecord/                                       (既存)
└── Assets.xcassets/                               ← 新規
    ├── Contents.json                              ← 新規
    └── AppIcon.appiconset/                        ← 新規
        ├── Contents.json                          ← 新規
        └── icon-1024.png                          ← 新規（スクリプト出力）

tools/                                             ← 新規ディレクトリ
└── generate-icon.swift                            ← 新規

docs/superpowers/
├── specs/
│   └── 2026-05-05-app-icon-design.md              ← 本ファイル
└── plans/
    └── 2026-05-05-app-icon.md                     ← 後で追加
```

## 10. 参照

- 親 spec: `docs/superpowers/specs/2026-05-04-sleep-rhythm-chart-design.md` §14 「残課題（v2 候補）」
- ブランドカラー出典: `SleepRecord/Views/Home/HomeView.swift:27-29`
- iOS 17+ Single Size AppIcon: Apple HIG「App icons」（2024 update）

## 11. 変更履歴

- **2026-05-05 (初版)**: 三日月 + 紫グラデ、CoreGraphics 生成スクリプト、Single Size 1024×1024 アセット構成で確定
