# DESIGN.md — freee

> このファイルはAIエージェントが正確な日本語UIを生成するためのデザイン仕様書です。
> 出典: https://freee.co.jp/ の computed style (2026-04-06 取得)

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: 業務UIはシステムフォント優先、Webサイトは Noto Sans JP
- **密度**: 情報密度高め（業務SaaS）
- **キーワード**: 信頼感、プロフェッショナル、クリーン、機能的

---

## 2. Color Palette & Roles

### Primary（ブランドカラー）

- **Primary** (`#2864f0`): メインの青。CTAボタン、リンク、アクション要素
- **Primary Dark** (`#1a50d0`): ホバー・プレス時

### Semantic（意味的な色）

- **Danger** (`#e0324b`): エラー、削除
- **Warning** (`#f5a623`): 警告、注意
- **Success** (`#20b25d`): 成功、完了

### Neutral（ニュートラル）

- **Text Primary** (`#595959`): 本文テキスト（純黒を避けたミディアムグレー）
- **Text Secondary** (`#8b8b8b`): 補足テキスト
- **Text Disabled** (`#b8b8b8`): 無効状態
- **Border** (`#d6d6d6`): 区切り線、枠
- **Background** (`#f5f5f5`): ページ背景
- **Surface** (`#ffffff`): カード面

---

## 3. Typography Rules

### 3.1 和文フォント（Webサイト）

- **ゴシック体**: Noto Sans JP, ヒラギノ角ゴ ProN, Meiryo, sans-serif

### 3.2 和文フォント（プロダクトUI）

- **システムフォント優先**: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif
- 理由: 業務ツールはシステムフォントが高速・安定

### 3.3 欧文フォント

- **サンセリフ**: Helvetica Neue, Arial

### 3.4 font-family 指定

```css
/* Webサイト本文 */
font-family: "Noto Sans JP", "ヒラギノ角ゴ ProN", "Meiryo", sans-serif;

/* プロダクトUI */
font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans JP", sans-serif;
```

### 3.5 文字サイズ・ウェイト階層

| Role | Size | Weight | Line Height | Letter Spacing | 備考 |
|------|------|--------|-------------|----------------|------|
| Heading 1 | 32px | 700 | 1.4 | 0 | |
| Heading 2 | 24px | 700 | 1.4 | 0 | |
| Heading 3 | 18px | 700 | 1.5 | 0 | |
| Body | 16px | 400 | 1.7 | 0 | |
| Caption | 13px | 400 | 1.6 | 0 | |
| Small | 11px | 400 | 1.5 | 0 | |

### 3.6 行間・字間

- **本文の行間 (line-height)**: 1.7
- **見出しの行間**: 1.4
- **本文の字間**: 0
- **見出しの字間**: 0

---

## 4. Component Stylings

### Buttons

**Primary**
- Background: `#2864f0`
- Text: `#ffffff`
- Padding: 10px 20px
- Border Radius: 8px
- Font Size: 14px
- Font Weight: 700

**Secondary**
- Background: `#ffffff`
- Text: `#2864f0`
- Border: 1px solid `#2864f0`
- Padding: 10px 20px
- Border Radius: 8px

### Inputs

- Background: `#ffffff`
- Border: 1px solid `#d6d6d6`
- Border (focus): 1px solid `#2864f0`
- Border Radius: 8px
- Padding: 8px 12px
- Font Size: 14px
- Height: 36px

### Cards

- Background: `#ffffff`
- Border: 1px solid `#d6d6d6`
- Border Radius: 8px
- Padding: 20px
- Shadow: `0 1px 2px rgba(0,0,0,0.08)`

---

## 5. Layout Principles

### Spacing Scale（4pxグリッド）

| Token | Value |
|-------|-------|
| XS | 4px |
| S | 8px |
| M | 16px |
| L | 24px |
| XL | 40px |
| XXL | 64px |

### Container

- Max Width: 1200px
- Padding (horizontal): 24px

---

## 6. Depth & Elevation

| Level | Shadow | 用途 |
|-------|--------|------|
| 0 | none | フラット |
| 1 | `0 1px 2px rgba(0,0,0,0.08)` | カード |
| 2 | `0 4px 8px rgba(0,0,0,0.1)` | ドロップダウン |
| 3 | `0 8px 16px rgba(0,0,0,0.12)` | モーダル |

---

## 7. Do's and Don'ts

### Do（推奨）

- プロダクトUIではシステムフォントを優先（Noto Sans JPはWebサイト用）
- 4pxグリッドに沿って余白を設定
- ボーダーラジウスは8pxを基準に統一

### Don't（禁止）

- テキストに純粋な `#000000` を使わない（`#595959` を使う）
- 青（#2864f0）と赤（#e0324b）を同じ画面に多用しない

---

## 9. Agent Prompt Guide

```
Primary Color: #2864f0
Text Color: #595959
Background: #f5f5f5
Font (Web): "Noto Sans JP", "ヒラギノ角ゴ ProN", "Meiryo", sans-serif
Font (Product UI): -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans JP", sans-serif
Body Size: 16px
Line Height: 1.7
Border Radius: 8px
Spacing: 4px grid (4/8/16/24/40/64)
```
