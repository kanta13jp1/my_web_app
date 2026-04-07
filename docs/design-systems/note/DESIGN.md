# DESIGN.md — note

> このファイルはAIエージェントが正確な日本語UIを生成するためのデザイン仕様書です。
> 出典: https://note.com/ の computed style (2026-04-06 取得)

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: シンプル・クリーン・コンテンツファースト
- **密度**: ゆったりとしたメディア/ブログ型
- **キーワード**: 明るい、余白重視、読みやすい、フラット、ミニマル

---

## 2. Color Palette & Roles

### Primary（ブランドカラー）

- **Primary** (`#5ac8b8`): メインのティールカラー。CTAボタン、リンク等に使用
- **Primary Dark** (`#4ab5a5`): ホバー・プレス時のプライマリカラー

### Semantic（意味的な色）

- **Danger** (`#f54033`): エラー、削除、危険な操作
- **Warning** (`#f5a623`): 警告、注意喚起
- **Success** (`#5ac8b8`): 成功、完了（プライマリと同色）

### Neutral（ニュートラル）

- **Text Primary** (`#222222`): 本文テキスト
- **Text Secondary** (`#717171`): 補足テキスト、ラベル
- **Text Disabled** (`#b0b0b0`): 無効状態のテキスト
- **Border** (`#e6e6e6`): 区切り線、入力欄の枠
- **Background** (`#f7f7f7`): ページ背景
- **Surface** (`#ffffff`): カード、モーダル等の面

---

## 3. Typography Rules

### 3.1 和文フォント

- **ゴシック体**: Noto Sans JP, ヒラギノ角ゴ ProN, Yu Gothic, sans-serif

### 3.2 欧文フォント

- **サンセリフ**: Helvetica Neue, Arial

### 3.3 font-family 指定

```css
/* 本文 */
font-family: "Noto Sans JP", "ヒラギノ角ゴ ProN", "Yu Gothic", sans-serif;
```

### 3.4 文字サイズ・ウェイト階層

| Role | Size | Weight | Line Height | Letter Spacing | 備考 |
|------|------|--------|-------------|----------------|------|
| Heading 1 | 28px | 700 | 1.5 | 0.04em | palt 適用 |
| Heading 2 | 22px | 700 | 1.5 | 0.04em | palt 適用 |
| Heading 3 | 18px | 700 | 1.6 | 0.04em | palt 適用 |
| Body | 18px | 400 | 2.0 | 0 | palt 非適用 |
| Caption | 14px | 400 | 1.7 | 0 | |
| Small | 12px | 400 | 1.5 | 0 | |

### 3.5 行間・字間

- **本文の行間 (line-height)**: 2.0（日本語ブログとして広め）
- **見出しの行間**: 1.5
- **本文の字間 (letter-spacing)**: 0（本文には適用しない）
- **見出しの字間**: 0.04em（見出しのみ palt + letter-spacing）

### 3.6 OpenType 機能

```css
/* 見出しのみ */
h1, h2, h3, h4, h5, h6, nav {
  font-feature-settings: "palt" 1;
}
/* 本文には palt を適用しない */
```

### 3.7 コンテンツ幅

- **記事本文の最大幅**: 620px（読みやすさ重視）
- **コンテナの左右パディング**: 20px

---

## 4. Component Stylings

### Buttons

**Primary**
- Background: `#5ac8b8`
- Text: `#ffffff`
- Padding: 12px 24px
- Border Radius: 4px
- Font Size: 14px
- Font Weight: 700

**Secondary**
- Background: `transparent`
- Text: `#5ac8b8`
- Border: 1px solid `#5ac8b8`
- Padding: 12px 24px
- Border Radius: 4px

### Inputs

- Background: `#ffffff`
- Border: 1px solid `#e6e6e6`
- Border (focus): 1px solid `#5ac8b8`
- Border Radius: 4px
- Padding: 10px 12px
- Font Size: 16px

### Cards

- Background: `#ffffff`
- Border: 1px solid `#e6e6e6`
- Border Radius: 8px
- Padding: 16px
- Shadow: `0 1px 4px rgba(0,0,0,0.08)`

---

## 5. Layout Principles

### Spacing Scale

| Token | Value |
|-------|-------|
| XS | 4px |
| S | 8px |
| M | 16px |
| L | 24px |
| XL | 40px |
| XXL | 64px |

### Container

- Max Width: 960px（サイト全体）/ 620px（記事本文）
- Padding (horizontal): 20px

---

## 6. Depth & Elevation

| Level | Shadow | 用途 |
|-------|--------|------|
| 0 | none | フラットな要素 |
| 1 | `0 1px 4px rgba(0,0,0,0.08)` | カード、ナビ |
| 2 | `0 4px 12px rgba(0,0,0,0.1)` | モーダル |
| 3 | `0 8px 24px rgba(0,0,0,0.12)` | ダイアログ |

---

## 7. Do's and Don'ts

### Do（推奨）

- 本文には `line-height: 2.0` を使う
- 見出しのみ `font-feature-settings: "palt" 1` を適用
- コンテンツ幅は620px以下に制限して読みやすさを確保
- ティールカラー（#5ac8b8）を差し色として控えめに使う

### Don't（禁止）

- 本文に `letter-spacing` を設定しない（palt と競合し可読性が下がる）
- 本文の `line-height` を 1.8 以下にしない
- 原色（赤・青・黄）を大量に使わない

---

## 9. Agent Prompt Guide

```
Primary Color: #5ac8b8
Text Color: #222222
Background: #f7f7f7
Font: "Noto Sans JP", "ヒラギノ角ゴ ProN", "Yu Gothic", sans-serif
Body Size: 18px
Body Line Height: 2.0
Heading Letter Spacing: 0.04em (headings only, with palt)
Body Letter Spacing: 0 (never apply to body)
Max Content Width: 620px
```
