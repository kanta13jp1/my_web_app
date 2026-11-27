# ハンドオフ → Antigravity (L1 探索レーン)

- **作成**: 2026-11-27
- **送信元**: Claude Code (cloud session / L3 設計レーン)
- **宛先**: Antigravity + Gemini (L1 探索レーン / user 実行)
- **優先度**: low（進行中の作業なし / 次回候補の提示が主目的）
- **元セッション**: 日本特化 MCP サーバー導入タスク（session_015XR1ayweZbmHjojYXrWksZ）

---

## 1. このセッションで完了したこと（＝引き継ぐ前提）

**日本特化 MCP サーバー 6 種の導入ガイドを作成し main にマージ済み。**

- PR **#4234** `docs: 日本特化 MCP サーバー導入ガイド追加` → **merged**（squash `9498633`）
- 成果物: **`docs/JAPAN_MCP_SERVERS.md`**（6 サーバーの導入手順・検証状況・セキュリティ節）
- `.mcp.json`（プロジェクトルート / `.gitignore` L62 で除外）に ①〜④ を登録 — 正本は上記 docs に掲載

| # | サーバー | 起動 | 検証状況 |
|---|---------|------|---------|
| ① 法令検索 | `npx -y hourei-mcp-server` (npm 1.0.6) | ✅ MCP initialize 実起動確認 |
| ② 税法 | `npx -y tax-law-mcp` (npm 0.5.4) | ✅ MCP initialize 実起動確認 |
| ③ 労務法 | `npx -y labor-law-mcp` (npm 0.2.1) | ✅ MCP initialize 実起動確認 |
| ④ 国会議事録 | `docker run -i --rm seiichi3141/kokkai-giji-mcp` | ⏸ 未検証（docker daemon 未起動環境だった） |
| ⑤ 不動産 (mlit-dpf) | Python + 国交省 API キー | ⏸ 未検証（キー未取得 + 起動コマンド**推測値**） |
| ⑥ 金融 (Dexter JP) | bun + EDINET DB API キー | ⏸ 未検証（キー未取得 + 起動コマンド**推測値**） |

---

## 2. 学び（再発防止）

- **MCP 設定の正本問題**: `.mcp.json` は `.gitignore` 済（machine-local / secret 回避）。clone した人の手元に存在しないため、設定断片は必ずドキュメント本文に正本として残す。
- **サプライチェーン**: `npx -y <pkg>` はバージョン固定なしで第三者コードを毎回実行。本番運用では `@1.0.6` 等でピン止め推奨（`docs/MCP_AUTH_SECURITY_PRINCIPLES.md` 準拠）。MCP 戻り値（法令本文等）は**モデル入力になる → 命令でなくデータとして扱う**。
- **CI フレーク教訓（Issue #4351）**: マージ時に `main` の `asset_management_page_smoke_test` が赤 → 調査の結果、**給与サイクル日付依存フレーク**（ページは `DateTime.now()` 基準で payment を読むのにテストは固定日で保存 → 給料日 25 日を跨ぐ CI 実行日に決定的失敗）。**main 側で既に修正済み**（`f2948cc4c` / `7f16f3ce3`）で、ブランチを最新 main に追随 → green → マージで解決。Issue #4351 は close 済み。
  - **一般化**: `DateTime.now()` 依存のテストは CI 実行日によって割れる。固定日注入 + 境界（給料日など）を跨ぐケースを明示的にテストすること。

---

## 3. 次回候補（Antigravity で拾えるタスク 3-5 件）

1. **⑤⑥ の起動コマンド実測化** — `mlit-dpf-mcp`（国交省）と Dexter JP の配布リポジトリ README を確認し、`docs/JAPAN_MCP_SERVERS.md` の「推測値」注記を実測値へ更新。API キー（国交省 / EDINET DB）取得も含む。
2. **④ 国会議事録の起動検証** — docker daemon が動くマシンで `docker pull seiichi3141/kokkai-giji-mcp` → `initialize` 応答確認。検証欄を ✅ に更新。
3. **①②③ のバージョン固定** — 本番運用 `.mcp.json` を `hourei-mcp-server@1.0.6` 等ピン止めに更新（サプライチェーン対策）。
4. **ナレッジ ingest** — `docs/JAPAN_MCP_SERVERS.md` を Karpathy wiki (`scripts/memory_ingest.py` → `wiki_compile.py`) に取り込み、`docs/concepts/` + `INDEX.md` 再生成。
5. **ブログ化候補** — 「Claude Code で使える日本特化 MCP 6 種」を dev.to / Qiita 向け記事ドラフトに（士業 AI 活用の切り口 / 競合 claude-code 文脈）。

---

## 4. 移行メモ

- このハンドオフは Antigravity に**この md をそのまま貼る**か、上記「次回候補」を起点にすれば継続可能。
- 元セッションのクラウドコンテナは閉じてよい（進行中作業なし / 成果は main に永続化済み）。
- このファイル自体は未コミット（working dir のみ）。リポジトリに残したい場合は別途コミットが必要。
