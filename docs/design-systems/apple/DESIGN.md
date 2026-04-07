# DESIGN.md — Apple Japan

> このファイルはAIエージェントが正確な日本語UIを生成するためのデザイン仕様書です。
> 出典: https://www.apple.com/jp/ の computed style (2026-04-06 取得)

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: プレミアム感、大胆な余白、写真・映像主体
- **密度**: ゆったり（マーケティングサイト型）
- **キーワード**: 洗練、エレガント、大胆、余白、プレミアム

---

## 2. Color Palette & Roles

### Primary（ブランドカラー）

- **Primary** (`#0066cc`): アクションリンク、CTAボタン
- **Primary Dark** (`#0055aa`): ホバー時

### Semantic（意味的な色）

- **Danger** (`#ff3b30`): iOS UIカラー準拠のレッド
- **Warning** (`#ff9500`): iOS UIカラー準拠のオレンジ
- **Success** (`#34c759`): iOS UIカラー準拠のグリーン

### Neutral（ニュートラル）

- **Text Primary** (`#1d1d1f`): 本文テキスト（純黒でなくほぼ黒）
- **Text Secondary** (`#6e6e73`): 補足テキスト（Apple特有のグレー）
- **Text Disabled** (`#aeaeb2`): 無効状態
- **Border** (`#d2d2d7`): 区切り線
- **Background** (`#f5f5f7`): ページ背景（Apple特有のライトグレー）
- **Surface** (`#ffffff`): カード面

---

## 3. Typography Rules

### 3.1 和文フォント（日本語版の特徴）

- **見出し**: SF Pro JP（英語版の "SF Pro Display" に対し日本語版は "SF Pro JP" が優先）
- **ゴシック体フォールバック**: Hiragino Sans, ヒラギノ角ゴシック, sans-serif

### 3.2 欧文フォント

- **サンセリフ**: SF Pro Display, SF Pro Text, Helvetica Neue

### 3.3 font-family 指定

```css
/* 見出し（日本語版） */
font-family: "SF Pro JP", "SF Pro Display", "SF Pro Icons",
             "Hiragino Kaku Gothic Pro", "ヒラギノ角ゴ Pro W3",
             "メイリオ", "Meiryo", "ＭＳ Ｐゴシック", sans-serif;

/* 本文 */
font-family: "SF Pro JP", "SF Pro Text", "SF Pro Icons",
             "Hiragino Kaku Gothic Pro", "ヒラギノ角ゴ Pro W3",
             "メイリオ", "Meiryo", "ＭＳ Ｐゴシック", sans-serif;
```

### 3.4 文字サイズ・ウェイト階層

| Role | Size | Weight | Line Height | Letter Spacing | 備考 |
|------|------|--------|-------------|----------------|------|
| Display | 56px | 700 | 1.07 | -0.357px | ヒーロー見出し |
| Heading 1 | 40px | 700 | 1.1 | -0.294px | セクション見出し |
| Heading 2 | 28px | 700 | 1.2 | -0.178px | |
| Heading 3 | 21px | 600 | 1.25 | 0 | |
| Body | 17px | 400 | 1.47 | 0 | |
| Caption | 14px | 400 | 1.43 | 0 | |
| Small | 12px | 400 | 1.33 | 0 | |

### 3.5 行間・字間の特徴

- **本文の行間**: 1.47（比較的タイト）
- **大見出しの letter-spacing**: マイナス値（-0.357px等）—欧文 SF Pro の特徴的なカーニング
- **日本語テキストの letter-spacing**: 基本 0（マイナス値は欧文専用）
- **body テキスト**: letter-spacing は 0

### 3.6 ボタン形状

- **ピルボタン**: border-radius: 980px（Apple特有の完全な丸）
- CTAボタンは大きく・余白を広くとる

---

## 4. Component Stylings

### Buttons

**Primary（ピルボタン）**
- Background: `#0066cc`
- Text: `#ffffff`
- Padding: 14px 30px
- Border Radius: 980px
- Font Size: 17px
- Font Weight: 400

**Secondary（ゴーストピルボタン）**
- Background: `transparent`
- Text: `#0066cc`
- Border: 1px solid `#0066cc`
- Border Radius: 980px
- Padding: 14px 30px

### Inputs

- Background: `#ffffff`
- Border: 1px solid `#d2d2d7`
- Border (focus): 1px solid `#0066cc`
- Border Radius: 12px
- Padding: 12px 16px
- Font Size: 17px

### Cards

- Background: `#ffffff`
- Border: none
- Border Radius: 18px
- Padding: 24px
- Shadow: `0 2px 12px rgba(0,0,0,0.1)`

---

## 5. Layout Principles

### Spacing Scale

| Token | Value |
|-------|-------|
| XS | 8px |
| S | 16px |
| M | 24px |
| L | 40px |
| XL | 80px |
| XXL | 120px |

### Container

- Max Width: 980px（Apple特有のタイトなコンテナ幅）
- Padding (horizontal): 22px

---

## 6. Depth & Elevation

| Level | Shadow | 用途 |
|-------|--------|------|
| 0 | none | フラット |
| 1 | `0 2px 12px rgba(0,0,0,0.08)` | カード |
| 2 | `0 8px 24px rgba(0,0,0,0.12)` | モーダル |
| 3 | `0 16px 40px rgba(0,0,0,0.16)` | ダイアログ |

---

## 7. Do's and Don'ts

### Do（推奨）

- 見出しに大きな余白とネガティブ letter-spacing（欧文部分のみ）
- ピルボタン（border-radius: 980px）でApple風の丸みを表現
- 背景は `#f5f5f7`（純白でなくApple特有のグレー）
- テキストは `#1d1d1f`（純黒を避ける）

### Don't（禁止）

- 日本語テキストにマイナス letter-spacing を適用しない（欧文専用）
- 過度な影（drop-shadow）を使わない（Appleはフラット寄り）
- `border-radius: 4px` の角張ったUIを使わない（Apple製品らしさが消える）

---

## 9. Agent Prompt Guide

```
Primary Color: #0066cc
Text Color: #1d1d1f
Secondary Text: #6e6e73
Background: #f5f5f7
Font: "SF Pro JP", "SF Pro Display", "Hiragino Kaku Gothic Pro", sans-serif
Body Size: 17px
Line Height: 1.47
Button Style: pill (border-radius: 980px)
Container Width: 980px
Letter Spacing: negative values for large Latin headings only; 0 for Japanese text
```
