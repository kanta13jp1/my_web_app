# 日本特化 MCP サーバー導入ガイド

> Claude Code / Codex で使える日本特化 MCP サーバー 6 種の導入設定。
> プロジェクトルート `.mcp.json` に ①〜④ を設定済 (= キー不要 / コマンド判明分)。
> ⑤⑥ は API キー必須のため本ドキュメントに手順を分離。

## 起動確認状況 (このセッションで検証)

| # | サーバー | パッケージ | 起動方法 | 検証 | `.mcp.json` |
|---|---------|-----------|---------|------|-------------|
| ① | 法令検索 | `hourei-mcp-server` (npm 1.0.6) | `npx -y hourei-mcp-server` | ✅ initialize 応答確認 | 登録済 (`hourei`) |
| ② | 税法 | `tax-law-mcp` (npm 0.5.4) | `npx -y tax-law-mcp` | ✅ initialize 応答確認 | 登録済 (`tax-law`) |
| ③ | 労務法 | `labor-law-mcp` (npm 0.2.1) | `npx -y labor-law-mcp` | ✅ initialize 応答確認 | 登録済 (`labor-law`) |
| ④ | 国会議事録 | `seiichi3141/kokkai-giji-mcp` (Docker) | `docker run -i --rm ...` | ⚠️ docker daemon 要 | 登録済 (`kokkai-giji`) |
| ⑤ | 不動産・地理空間 | `mlit-dpf-mcp` (Python) | 国交省 API キー必須 | ⏸ キー未投入 | 未登録 (下記参照) |
| ⑥ | 金融分析 (Dexter JP) | EDINET DB (bun) | EDINET DB API キー必須 | ⏸ キー未投入 | 未登録 (下記参照) |

> 検証 = MCP `initialize` ハンドシェイクに正常応答したことを確認 (node v22 / npx 10.9)。
> ④ は remote/web 環境では docker daemon 未起動のため config のみ。docker 稼働マシンで有効。

## ① 法令検索 MCP

- e-Gov 法令 API に接続。法令名検索 / 条文取得 / 改正履歴。
- キー不要。`.mcp.json` の `hourei` として設定済。

## ② 税法 MCP

- e-Gov + 国税庁の通達・裁決事例。24 主要税法 / 17 行政通達 / 1,950 裁決事例。
- ハルシネーション防止設計 (条文言及時は必ずツールで原文取得を強制)。
- キー不要。`.mcp.json` の `tax-law` として設定済。

## ③ 労務法 MCP

- 45 労働関連法令 + 厚労省通達 (労基署・安全衛生含む)。②と同作者 / MIT。
- キー不要。`.mcp.json` の `labor-law` として設定済。

## ④ 国会議事録 MCP

- 国立国会図書館 API。国会議事録の全文検索 + URL/PDF 取得。
- Docker イメージ pull が必要:

```bash
docker pull seiichi3141/kokkai-giji-mcp
```

- `.mcp.json` の `kokkai-giji` として設定済 (`docker run -i --rm seiichi3141/kokkai-giji-mcp`)。
- docker daemon が動いているマシンでのみ起動可能。最終更新 2026-01 (やや古いが動作可)。

## ⑤ 不動産・地理空間 MCP (mlit-dpf-mcp) — API キー要

- 国交省 公式。不動産情報ライブラリ API (地価・防災データ等)、18+ ツール。
- ⚠️ アルファ版 (「動作保証は行っておりません」と明記)。
- 前提: Python 3.10+ / 国交省 API キー (不動産情報ライブラリで発行)。

導入後、キーを環境変数に入れて `.mcp.json` に以下を追記:

```jsonc
"mlit-dpf": {
  "command": "python",
  "args": ["-m", "mlit_dpf_mcp"],   // ← 実パッケージの起動方法に合わせて要調整
  "env": { "MLIT_API_KEY": "${MLIT_API_KEY}" }
}
```

> 正確な起動コマンドは配布リポジトリ (国交省 mlit-dpf-mcp) の README で確認のこと。
> API キーは `.mcp.json` に直書きせず `${MLIT_API_KEY}` で環境変数展開する。

## ⑥ 金融分析 MCP (Dexter JP / EDINET DB) — API キー要

- 上場企業 約 3,800 社の構造化財務データ。100+ 財務指標 / DCF / 33 業種スクリーニング。
- Slack・Discord・LINE 対応 (v0.2.0)、複数 LLM 対応。
- 前提: bun / EDINET DB API キー。

導入後、キーを環境変数に入れて `.mcp.json` に以下を追記:

```jsonc
"dexter-jp": {
  "command": "bun",
  "args": ["run", "start"],   // ← 実リポジトリの起動 script に合わせて要調整
  "env": { "EDINET_DB_API_KEY": "${EDINET_DB_API_KEY}" }
}
```

> 正確な起動コマンドは Dexter JP リポジトリの README で確認のこと。

## 使い方

`.mcp.json` があるプロジェクトで Claude Code を起動すると ①〜④ が自動でロードされる。
初回は各サーバーの信頼確認プロンプトが出る場合がある。`/mcp` でロード状況を確認できる。

例:
- 「労働基準法 第36条は?」→ ③ が条文原文を返す
- 「この経費は損金算入できる?」→ ② が根拠条文付きで回答
- 「〇〇大臣の AI に関する答弁は?」→ ④ が議事録から取得
