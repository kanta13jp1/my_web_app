# DESIGN.md — SmartHR

> このファイルはAIエージェントが正確な日本語UIを生成するためのデザイン仕様書です。
> 出典: https://smarthr.jp/ の computed style (2026-04-06 取得)

---

## 1. Visual Theme & Atmosphere

- **デザイン方針**: 業務UIの信頼感と、人事HR領域の親しみやすさを両立
- **密度**: 中程度（HR業務ツール）
- **キーワード**: 誠実、安心感、使いやすい、モダン、整理された

---

## 2. Color Palette & Roles

### Primary（ブランドカラー）

- **Primary** (`#0077c7`): プロダクトブルー。CTAボタン、リンク、アクション要素
- **Primary Dark** (`#005fa3`): ホバー・プレス時
- **Primary Light** (`#e8f4ff`): 背景ハイライト、選択状態

### Semantic（意味的な色）

- **Danger** (`#e01e5a`): エラー、削除
- **Warning** (`#f5a623`): 警告
- **Success** (`#2eb886`): 成功、完了

### Neutral（ニュートラル）

- **Text Primary** (`#333333`): 本文テキスト
- **Text Secondary** (`#666666`): 補足テキスト
- **Text Disabled** (`#aaaaaa`): 無効状態
- **Border** (`#d6d6d6`): 区切り線
- **Background** (`#f8f8f8`): ページ背景
- **Surface** (`#ffffff`): カード面

---

## 3. Typography Rules

### 3.1 和文フォント

- **ゴシック体**: Yu Gothic（@font-face でMediumウェイトを400にマッピング）, ヒラギノ角ゴ ProN, Meiryo, sans-serif

**Yu Gothic 400マッピングの特徴**:
```css
@font-face {
  font-family: "Yu Gothic";
  src: local("Yu Gothic Medium");
  font-weight: 400;
}
@font-face {
  font-family: "Yu Gothic";
  src: local("Yu Gothic Bold");
  font-weight: bold;
}
```
理由: Windows の Yu Gothic Regular は極細すぎるため、Mediumウェイトを regular として使用する。

### 3.2 欧文フォント

- **サンセリフ**: Helvetica Neue, Arial

### 3.3 font-family 指定

```css
font-family: "Yu Gothic", "ヒラギノ角ゴ ProN", "Hiragino Kaku Gothic ProN",
             "Meiryo", "メイリオ", sans-serif;
```

### 3.4 文字サイズ・ウェイト階層

| Role | Size | Weight | Line Height | Letter Spacing | 備考 |
|------|------|--------|-------------|----------------|------|
| Heading 1 | 30px | 700 | 1.4 | 0 | |
| Heading 2 | 22px | 700 | 1.4 | 0 | |
| Heading 3 | 17px | 700 | 1.5 | 0 | |
| Body | 14px | 400 | 1.5 | 0 | |
| Caption | 12px | 400 | 1.5 | 0 | |
| Small | 11px | 400 | 1.4 | 0 | |

### 3.5 行間・字間

- **本文の行間**: 1.5（業務UIとして適切な密度）
- **見出しの行間**: 1.4
- **文字間**: 全て 0（letter-spacingは使用しない）

---

## 4. Component Stylings

### Buttons

**Primary**
- Background: `#0077c7`
- Text: `#ffffff`
- Padding: 10px 20px
- Border Radius: 6px
- Font Size: 14px
- Font Weight: 700

**Secondary**
- Background: `#ffffff`
- Text: `#0077c7`
- Border: 1px solid `#0077c7`
- Padding: 10px 20px
- Border Radius: 6px

**Danger**
- Background: `#e01e5a`
- Text: `#ffffff`
- Border Radius: 6px

### Inputs

- Background: `#ffffff`
- Border: 1px solid `#d6d6d6`
- Border (focus): 1px solid `#0077c7`
- Border Radius: 6px
- Padding: 8px 12px
- Font Size: 14px
- Height: 34px

### Cards

- Background: `#ffffff`
- Border: 1px solid `#d6d6d6`
- Border Radius: 6px
- Padding: 16px
- Shadow: `0 1px 2px rgba(0,0,0,0.06)`

---

## 5. Layout Principles

### Spacing Scale（8pxグリッド）

| Token | Value |
|-------|-------|
| XS | 4px |
| S | 8px |
| M | 16px |
| L | 24px |
| XL | 32px |
| XXL | 48px |

### Container

- Max Width: 1280px
- Padding (horizontal): 24px

---

## 6. Depth & Elevation

| Level | Shadow | 用途 |
|-------|--------|------|
| 0 | none | フラット |
| 1 | `0 1px 2px rgba(0,0,0,0.06)` | カード |
| 2 | `0 4px 8px rgba(0,0,0,0.1)` | ドロップダウン |
| 3 | `0 8px 16px rgba(0,0,0,0.1)` | モーダル |

---

## 7. Do's and Don'ts

### Do（推奨）

- WindowsでのYu Gothic表示のため @font-face で Medium→400 マッピングを使う
- border-radius は6pxで統一
- 8pxグリッドに従った余白設定
- line-height は業務UIとして 1.5 を基準にする

### Don't（禁止）

- `letter-spacing` を使わない（SmartHRは全て0）
- line-height を 1.4 以下にしない（特に日本語テキスト）

---

## 9. Agent Prompt Guide

```
Primary Color: #0077c7
Text Color: #333333
Background: #f8f8f8
Font: "Yu Gothic", "ヒラギノ角ゴ ProN", "Meiryo", sans-serif
Note: Yu Gothic requires @font-face mapping (Medium→400, Bold→bold) for Windows
Body Size: 14px
Line Height: 1.5
Border Radius: 6px
Spacing: 8px grid (4/8/16/24/32/48)
Letter Spacing: 0 (never use)
```
