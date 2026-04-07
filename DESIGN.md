# DESIGN.md — note (参照デザインシステム)

> **出典**: [awesome-design-md-jp](https://github.com/kzhrknt/awesome-design-md-jp) より取得  
> note（https://note.com/）のデザイン仕様書。  
> 実サイトの CSS（Tailwind CSS v3.4.1 + Svelte スコープドスタイル）および CSS Custom Properties に基づく。  
>
> **このプロジェクトへの適用方針**: `docs/DESIGN.md` を参照。note のカラー/タイポ仕様を Flutter コード生成の際の参考基準として使用する。

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: 読みやすさを最優先にした、落ち着いたメディアプラットフォーム。書き手と読み手の体験を大切にし、コンテンツが主役のデザイン
- **密度**: ゆったりとした余白。記事コンテンツエリアは 620px 幅で可読性を重視
- **キーワード**: 読みやすい、温かい、ミニマル、コンテンツファースト、落ち着き
- **特徴**: 純粋な黒（`#000000`）ではなく、ほぼ黒の `#08131a` を使用し、柔らかい読書体験を提供。ダークモード完全対応

---

## 2. Color Palette & Roles

### Primary（ブランドカラー）

- **note Green** (`#5ac8b8`): ブランドアイデンティティカラー。ロゴ、アクセントに使用

### Semantic（意味的な色） — CSS Custom Properties 実測値

- **Success** — surface: `#1e7b65`, text: `#1e7b65`, subdued: `#e6f6f2`
- **Danger** — surface: `#b22323`, text: `#b22323`, subdued: `#fdf3f3`
- **Caution** — surface: `#916626`, text: `#916626`, subdued: `#fefbea`
- **Like** — surface: `#d13e5c`, text: `#d13e5c`
- **Offer** — surface: `#d13e5c`, text: `#d13e5c`
- **Badge** (`#d53c21`): 通知バッジ
- **Point** — text: `#8b7f2c`

### Neutral — Gray Scale

- **Gray 900** (`#08131a`): 本文テキスト（ほぼ黒）
- **Gray 800** (`#202a30`): 濃いテキスト
- **Gray 700** (`#363f42`): 強調テキスト
- **Gray 600** (`#5a656b`): セカンダリテキスト
- **Gray 500** (`#7e888f`): 薄いテキスト
- **Gray 400** (`#9ca7ad`): プレースホルダー
- **Gray 300** (`#aeb7bd`): 無効状態
- **Gray 200** (`#c5ccd1`): 薄いボーダー
- **Gray 100** (`#dce0e3`): ボーダー
- **Gray 50** (`#f5f8fa`): セカンダリ背景

### Text（テキスト色 — CSS Custom Properties）

- **Text Primary** (`#08131a`): 本文テキスト。ダーク: `hsla(0,0%,100%,0.90)`
- **Text Secondary** (`rgba(8,19,26,0.66)`): 補足テキスト。ダーク: `hsla(0,0%,100%,0.66)`
- **Text Clickable Icon** (`rgba(8,19,26,0.50)`): クリック可能アイコン
- **Text Disabled** (`rgba(8,19,26,0.50)`): 無効テキスト
- **Text Invert** (`#ffffff`): 反転テキスト（暗い背景上）
- **Text Placeholder** (`#888`): プレースホルダー

### Surface & Borders

- **Background Primary** (`#fff`): ページ背景
- **Background Secondary** (`#f5f8fa`): セクション背景
- **Surface Normal** (`#fff`): カード等の面
- **Surface Primary** (`#08131a`): プライマリ面（CTA等）。reaction: `#202a30`
- **Border Default** (`rgba(8,19,26,0.14)`): 標準ボーダー
- **Border Strong** (`rgba(8,19,26,0.22)`): 強いボーダー
- **Border Focus** (`#292d9e`): フォーカスリング（darkblue-600）

### Accent / Action

- **Custom Accent** (`#08131a`): CTA（ライトモード）。reaction: `#202a30`

### Social Colors

- **note** (`#5ac8b8`), **Twitter/X** (`#000`), **Facebook** (`#1877f2`), **Hatena** (`#00a4df`), **LINE** (`#00b900`), **Threads** (`#000`)

---

## 3. Typography Rules

### 3.1 和文フォント

**ゴシック体（デフォルト）**:
- ヒラギノ角ゴ ProN（macOS）
- Noto Sans JP（Windows フォールバック）
- メイリオ（Windows 追加フォールバック）

**明朝体（記事本文のオプション）**:
- ヒラギノ明朝 ProN / Pro（macOS）
- BIZ UDPMincho（Windows）
- 游明朝 / Yu Mincho（クロスプラットフォーム）
- MS PMincho（レガシー Windows）

### 3.2 欧文フォント

- **サンセリフ**: Helvetica Neue, Arial
- **セリフ**: 明朝体フォールバック内で対応
- **等幅**: SFMono-Regular, Consolas, Menlo, Courier
- **数字専用**: Open Sans（数字の可読性向上）

### 3.3 font-family 指定

```css
/* デフォルト（ゴシック体） */
font-family: "Helvetica Neue", "Hiragino Sans", "Hiragino Kaku Gothic ProN",
  Arial, "Noto Sans JP", Meiryo, sans-serif;

/* 明朝体（記事本文オプション） */
font-family: "Hiragino Mincho ProN", "Hiragino Mincho Pro", HGSMinchoE,
  "Yu Mincho", YuMincho, "MS PMincho", serif;

/* 等幅 */
font-family: SFMono-Regular, Consolas, Menlo, Courier, monospace;

/* 数字専用 */
font-family: "Open Sans", sans-serif;
```

**フォールバックの考え方**:
- 欧文フォント（Helvetica Neue）を先に指定し、欧文の表示品質を優先
- macOS の和文フォント（ヒラギノ）→ Windows の和文フォント（Noto Sans JP, メイリオ）の順
- 明朝体は記事本文のオプションとして別スタックを用意

### 3.4 文字サイズ・ウェイト階層

**記事ページ**

| Role | Size | Weight | Line Height | Letter Spacing | palt |
|------|------|--------|-------------|----------------|------|
| Article Title (h1) | 32px | 700 | 48px (×1.5) | 1.28px (0.04em) | あり |
| Heading 2 | 28px | 700 | 36px (×1.286) | 1.12px (0.04em) | あり |
| Body (p) | 18px | 400 | 36px (×**2.0**) | normal | なし |
| Input | 14px | 400 | 21px (×1.5) | normal | なし |

**トップページ**

| Role | Size | Weight | Line Height | Letter Spacing | palt |
|------|------|--------|-------------|----------------|------|
| Heading 2 | 16px | 600 | 24px (×1.5) | normal | なし |
| Heading 3 | 16px | 600 | 24px (×1.5) | 0.64px (0.04em) | あり |
| Caption (p) | 12px | 600 | 18px (×1.5) | normal | なし |
| Button | 16px | 400 | 24px (×1.5) | normal | なし |

### 3.5 行間・字間

**重要ルール**:
- `letter-spacing: 0.04em` と `palt` は**見出し専用**。本文には適用しない
- 記事本文の可読性は `font-size: 18px` + `line-height: 2.0` のゆったりした行間で確保
- トップページの見出しは weight `600`（semibold）、記事ページは `700`（bold）と使い分け

### 3.6 禁則処理・改行ルール

```css
body {
  word-wrap: break-word;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  font-kerning: auto;
}
```

### 3.7 OpenType 機能

```css
/* 見出し (h1, h2, トップ h3) にのみ適用 */
font-feature-settings: "palt";

/* 本文 (p), body, button, input, a には適用しない */
font-feature-settings: normal;
```

---

## 4. Component Stylings

### Buttons

**Primary（CTA）**
- Background: `#08131a`（ライトモード）
- Text: `#ffffff`
- Font Size: 1rem (16px) / Font Weight: 700

### Cards（記事カード）

- Background: `#fff`
- Border: `rgba(8,19,26,0.14)`
- Border Radius: 12px
- Shadow: `0px 1px 3px 1px rgba(0,0,0,0.14), 0px 1px 2px 0px rgba(0,0,0,0.22)`

### Navigation

- Background: `#fff`
- Border Bottom: `rgba(8,19,26,0.14)`
- Height: 64px（デスクトップ）/ 48px（モバイル）

---

## 5. Layout Principles

| Area | Width | 用途 |
|------|-------|------|
| Main Content | 940px | メインコンテンツ幅 |
| Article (Small) | 620px | 記事本文、読み物コンテンツ |
| Timeline | 580px | タイムラインフィード |
| Two-Column Main | 610px | 2カラムレイアウトのメイン |
| Two-Column Sub | 280px | サイドバー |

---

## 6. Depth & Elevation

| Level | Shadow | 用途 |
|-------|--------|------|
| `--elevation-1` | `0px 1px 3px 1px rgba(0,0,0,0.14), 0px 1px 2px 0px rgba(0,0,0,0.22)` | カード |
| `--elevation-4` | `0px 4px 8px 3px rgba(0,0,0,0.14), 0px 1px 3px 0px rgba(0,0,0,0.22)` | ドロップダウン |
| `--elevation-6` | `0px 6px 10px 4px rgba(0,0,0,0.14), 0px 2px 3px 0px rgba(0,0,0,0.22)` | モーダル |

---

## 7. Do's and Don'ts

### Do（推奨）

- テキスト色は `#08131a`（ほぼ黒）を使い、純粋な `#000000` を避ける
- セカンダリテキストは同じ色相の opacity 違い（`rgba(8,19,26,0.66)`）で表現する
- 記事本文は `font-size: 18px` + `line-height: 2.0` で組む
- `letter-spacing: 0.04em` と `palt` は**見出し (h1, h2) にのみ**適用する
- ダークモードでは全色を CSS Custom Properties で切り替える
- 記事コンテンツ幅は 620px を維持する

### Don't（禁止）

- 純粋な `#000000` をテキストに使わない（コントラストが強すぎて読み疲れする）
- 記事コンテンツ幅を 620px 以上にしない
- ブランドカラー `#5ac8b8` をテキストに使わない（白背景でコントラスト不足）
- `letter-spacing: 0.04em` や `palt` を本文 (p) に適用しない

---

## 8. Responsive Behavior

### Breakpoints

| Name | Width |
|------|-------|
| XS | 361px |
| SM | 481px |
| MD | 769px |
| LG | 941px |
| XL | 1280px |
| 2XL | ≤ 2048px |

- 最小タッチターゲット: **44px × 44px**
- Dark Mode: `prefers-color-scheme: dark` + `.theme-dark` クラス対応

---

## 9. Agent Prompt Guide

### クイックリファレンス

```
Brand Color: #5ac8b8（ロゴ・アクセント用）
CTA Background: #08131a（ライトモード）
Text Primary: #08131a
Text Secondary: rgba(8,19,26,0.66)
Background: #ffffff / Background Secondary: #f5f8fa
Border: rgba(8,19,26,0.14)
Focus Ring: #292d9e

Font (default): "Helvetica Neue", "Hiragino Sans",
  "Hiragino Kaku Gothic ProN", Arial, "Noto Sans JP", Meiryo, sans-serif

Body (top): 16px / line-height: 1.5 / letter-spacing: normal
Body (article): 18px / line-height: 2.0 / letter-spacing: normal
Heading: letter-spacing: 0.04em + font-feature-settings: "palt"
Article Width: 620px
```

### このプロジェクト (自分株式会社) への適用方針

Flutter Web では CSS Custom Properties が使えないため、以下の方針で適用する:

1. **カラー参照**: `docs/DESIGN.md` の Flutter カラー定義を優先。note の gray scale (`#08131a` 系) は Light テーマのテキストカラーの参考値として使用
2. **タイポグラフィ**: `ThemeService._buildJaTextTheme()` に note 準拠の line-height (body: 1.7〜2.0, heading: 1.4) 適用済み
3. **見出し letterSpacing**: note 実測値 (H1: 0.04em = 1.28px) を参考に `ThemeService` で設定済み
4. **カードシャドウ**: note の `--elevation-1` を Flutter `BoxShadow` に変換して使用
5. **コンテンツ幅**: 記事・長文コンテンツは `maxWidth: 620` を目安に設定

---

*出典: [awesome-design-md-jp](https://github.com/kzhrknt/awesome-design-md-jp/blob/main/design-md/note/DESIGN.md) — 2026-04-07 取得*
