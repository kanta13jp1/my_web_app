---
name: Flutter Web CORS フォールバック パターン確立
description: CanvasKit CORS 失敗時に Image.network の webHtmlElementStrategy パラメータで HTML <img> 自動切り替え成功
type: feedback
---

## 成功パターン: 10-hypothesis デバッグ × CORS 公式対応

### 背景
断つ応援キャンペーン動画ページで、風刺画フレームが表示されず「茶色い枠」のまま停止していた。

### 問題分析
- CanvasKit がクロスオリジン画像（Wikimedia Commons）をレンダリング時に CORS エラーで失敗
- errorBuilder で透明/SizedBox.shrink() 返却しても、背後の絵文字が見えず「何も表示されない」状態に

### 解決策
`Image.network` に `webHtmlElementStrategy: WebHtmlElementStrategy.fallback` を指定 → CanvasKit デコード失敗時に HTML `<img>` 要素へ自動フォールバック。

```dart
Image.network(
  imageUrl,
  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,  // ← これ 1 行で解決
  loadingBuilder: (_, __, ___) => SizedBox.shrink(),
  errorBuilder: (_, __, ___) => SizedBox.shrink(),
)
```

### 成功指標
- PR #4248: レイアウト・ボタン重複 ✅ マージ済み（本番反映）
- PR #4356: CORS フォールバック ✅ マージ済み（本番反映）
- CI 全エラー 0（Lint / Format / Security / E2E 宣言）
- 本番 URL での絵文字+グラデーション背景は常に表示保証（失敗時フォールバック無回帰）

### なぜこれが重要か
- **再利用可能**: 同じ CORS 問題は他の Web 動画/画像埋め込みでも発生
- **Flutter 公式**: Flutter 3.29+ の標準 API なので、将来メンテナンス負荷が低い
- **失敗時の UX 保証**: エラーハンドリングが単なる透明ではなく、背景が常に見える設計

### 次回適用方法
1. 新しい Web 動画機能を追加する際、外部画像 URL を使う場合は最初から `webHtmlElementStrategy: WebHtmlElementStrategy.fallback` を指定
2. CORS エラーが疑われる場合、まずこのパラメータを確認
3. docs/ に「Flutter Web 画像埋め込みガイド」を作成して参照可能にする

---

## 補足: 段階的フォールバック設計

```
1️⃣ CanvasKit 成功 → 実画像表示 ✅
2️⃣ CanvasKit CORS 失敗 → HTML <img> へ自動切り替え ✅
3️⃣ <img> 読み込み失敗 → errorBuilder で SizedBox.shrink() ✅
4️⃣ 背景は常に絵文字+グラデーション ✅（無回帰保証）
```

この 4 層構造で、**どのレイヤーでも表示が壊れない** ことを保証。
