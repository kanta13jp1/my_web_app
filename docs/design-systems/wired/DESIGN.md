# DESIGN.md — WIRED.jp

> このファイルはAIエージェントが正確な日本語UIを生成するためのデザイン仕様書です。
> 出典: https://wired.jp/ の computed style (2026-04-06 取得)

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: テクノロジーメディアらしいエッジの効いたデザイン、ブランドフォント使用
- **密度**: ゆったり（メディア・雑誌型）
- **キーワード**: クール、モノクロ、エッジ、インテリジェント、メディア感

---

## 2. Color Palette & Roles

### Primary（ブランドカラー）

- **Primary** (`#000000`): 純粋な黒がブランドカラー
- **Primary Accent** (`#ffff00`): WIREDのシグネチャー黄色（強調・アクセント）

### Semantic（意味的な色）

- **Danger** (`#ff3b30`): エラー
- **Warning** (`#ff9500`): 警告
- **Success** (`#34c759`): 成功

### Neutral（ニュートラル）

- **Text Primary** (`#000000`): 本文テキスト（純粋な黒を使用—WIREDの特徴）
- **Text Secondary** (`#666666`): 補足テキスト
- **Text Disabled** (`#999999`): 無効状態
- **Border** (`#e0e0e0`): 区切り線
- **Background** (`#ffffff`): ページ背景（真っ白）
- **Surface** (`#f4f4f4`): カード面（ライトグレー）

---

## 3. Typography Rules

### 3.1 和文フォント

- **ゴシック体**: Noto Sans JP, ヒラギノ角ゴ ProN, sans-serif
- **本文全体に palt を適用**（他サービスと異なりグローバル設定）

### 3.2 欧文フォント（ブランドフォント）

- **WiredMono**: WIRED独自のモノスペースブランドフォント（見出しに使用）
- **サンセリフフォールバック**: Helvetica Neue, Arial

### 3.3 font-family 指定

```css
/* 見出し（ブランドフォント） */
font-family: "WiredMono", "Noto Sans JP", "ヒラギノ角ゴ ProN", sans-serif;

/* 本文 */
font-family: "Noto Sans JP", "ヒラギノ角ゴ ProN", "ヒラギノ角ゴシック", sans-serif;
```

### 3.4 文字サイズ・ウェイト階層

| Role | Size | Weight | Line Height | Letter Spacing | 備考 |
|------|------|--------|-------------|----------------|------|
| Display | 48px | 900 | 1.1 | 0 | WiredMono使用 |
| Heading 1 | 32px | 700 | 1.25 | 0 | |
| Heading 2 | 24px | 700 | 1.3 | 0 | |
| Heading 3 | 18px | 700 | 1.4 | 0 | |
| Body | 16px | 400 | 1.75 | 0 | |
| Caption | 13px | 400 | 1.6 | 0 | |
| Small | 11px | 400 | 1.5 | 0 | |

### 3.5 行間・字間

- **本文の行間 (line-height)**: 1.75（長文記事に適した広め）
- **見出しの行間**: 1.1〜1.3（タイト）
- **letter-spacing**: 0（全要素で使用しない）

### 3.6 OpenType 機能（WIRED特有）

```css
/* 本文グローバルに palt を適用（珍しい設定） */
body {
  font-feature-settings: "palt" 1;
}
```

他サービスが見出しのみに palt を適用するのに対し、WIREDは body 要素全体に適用している。
これにより日本語文字が全体的にプロポーショナルに詰められ、雑誌的な印象を与える。

---

## 4. Component Stylings

### Buttons

**Primary**
- Background: `#000000`
- Text: `#ffffff`
- Padding: 12px 24px
- Border Radius: 0px（角張ったデザイン）
- Font Size: 14px
- Font Weight: 700
- Text Transform: uppercase

**Secondary**
- Background: `#ffffff`
- Text: `#000000`
- Border: 1px solid `#000000`
- Padding: 12px 24px
- Border Radius: 0px

**Accent**
- Background: `#ffff00`
- Text: `#000000`
- Border Radius: 0px

### Inputs

- Background: `#ffffff`
- Border: 1px solid `#000000`
- Border (focus): 2px solid `#000000`
- Border Radius: 0px
- Padding: 10px 12px
- Font Size: 16px

### Cards

- Background: `#ffffff`
- Border: 1px solid `#e0e0e0`
- Border Radius: 0px
- Padding: 0
- Shadow: none（フラットデザイン）

---

## 5. Layout Principles

### Spacing Scale

| Token | Value |
|-------|-------|
| XS | 8px |
| S | 16px |
| M | 24px |
| L | 40px |
| XL | 64px |
| XXL | 96px |

### Container

- Max Width: 1140px
- Padding (horizontal): 24px

### Grid

- Columns: 12
- Gutter: 24px

---

## 6. Depth & Elevation

| Level | Shadow | 用途 |
|-------|--------|------|
| 0 | none | フラット（WIREDの基本） |
| 1 | `none` | カード（ボーダーのみ） |
| 2 | `0 2px 8px rgba(0,0,0,0.15)` | ドロップダウン（最小限） |

---

## 7. Do's and Don'ts

### Do（推奨）

- 黒と白のモノクロベース＋黄色のアクセントで WIRED らしさを表現
- `font-feature-settings: "palt" 1` を body 全体に適用（WIRED特有）
- ボーダーラジウスは 0px（角張ったエッジの効いたデザイン）
- 見出しは WiredMono やウルトラボールドで力強く

### Don't（禁止）

- 丸いボタン（border-radius: 8px以上）を使わない—WIREDらしさが消える
- カードに影を付けない（ボーダーのみ）
- 多色を使わない（黒・白・黄の3色が基本）

---

## 9. Agent Prompt Guide

```
Primary Color: #000000 (black)
Accent Color: #ffff00 (WIRED yellow)
Text Color: #000000 (pure black — unique to WIRED)
Background: #ffffff
Font (display): "WiredMono", "Noto Sans JP", sans-serif
Font (body): "Noto Sans JP", "ヒラギノ角ゴ ProN", sans-serif
Body Size: 16px
Line Height: 1.75
Border Radius: 0 (sharp corners)
Shadow: none (flat design with borders)
OpenType: font-feature-settings: "palt" 1 on body element globally
```
