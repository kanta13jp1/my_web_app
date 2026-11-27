# MEMORY — 自分株式会社 Claude Code セッション永続記録

> Karpathy 4-サイクル実装（Ingest → Compile → Query → Lint）
> 参照: [`docs/NOTEBOOKLM_GUIDE.md`](../../docs/NOTEBOOKLM_GUIDE.md)

## インデックス

### 成功パターン
- [`feedback_success_20261127.md`](feedback_success_20261127.md) — Flutter Web CORS フォールバック パターン確立 (10-hypothesis × webHtmlElementStrategy 成功)

### 新規発見
- [`project_20261127.md`](project_20261127.md) — Flutter Web CORS 制約と公式対応メカニズム (CanvasKit / webHtmlElementStrategy / Wikimedia API)

---

## 完了タスク

✅ **断つ応援キャンペーン動画ページ改善**
- PR #4248: レイアウト・ボタン重複 修正 ✅ マージ済み
- PR #4356: CORS フォールバック (webHtmlElementStrategy) ✅ マージ済み
- 本番環境: https://my-web-app-b67f4.web.app/sobriety-campaign （絵文字背景 + 画像フォールバック 動作確認済み）

---

## 未完了タスク

なし（本セッションで全完了）

---

## 次回優先タスク候補

| 優先度 | タスク | 推定規模 | 分類 |
|--------|--------|----------|------|
| 🔴 最高 | **その他の Web 動画埋め込み機能への CORS 対応展開** | M | 技術負債削減 |
| 🟡 高  | 競合対抗機能：Slack/Discord 連携ショート動画共有 | L | 商品拡張 |
| 🟢 中  | docs/ に「Flutter Web 画像埋め込みガイド」作成 | S | 知識化 |

---

## Philosophy Alignment (Claude-Session-20261127)

### 実装内容
- 断つ応援キャンペーン動画ページ: レイアウト修正 + CORS フォールバック

### 該当原則
- 原則 2: **ミッション駆動** — キャンペーンの核心「実画像の風刺画」をユーザーに届ける
- 原則 5: **商品=ユーザー価値** — 壊れた表示を修正し、ユーザーが確実に見られる
- 原則 6: **資本=時間** — 標準 API 1 行で解決（無駄なカスタム実装なし）

### 整合性スコア
9/9 ✅

### 理念的貢献
ユーザーが「断つ」という決断を促す視覚的核が確保された。商品の存在意義を支える技術投資。

### 懸念事項
なし

---

<!-- wrap-up 20261127
✅ 完了
- 成功パターン: 1件
- 新規発見: 1件
- 訂正: 0件
- NotebookLM: 蓄積待機
- Philosophy Alignment: 9/9 ✅
- 次回優先: CORS対応の他機能展開
-->
