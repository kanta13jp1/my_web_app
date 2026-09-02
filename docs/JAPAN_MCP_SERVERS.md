# 日本特化 MCP サーバー導入ガイド

> Claude Code / Codex で使える日本特化 MCP サーバー 6 種の導入設定。
> ①〜④ の `.mcp.json` 断片は下記「`.mcp.json` (①〜④)」節に記載 (= キー不要 / コマンド判明分)。
> ⑤⑥ は API キー必須 + 起動コマンド未確定のため本ドキュメントに手順を分離。
> 実起動で検証済みは ①②③ のみ (④⑤⑥ は未検証 — 表参照)。

## 起動確認状況 (このセッションで検証)

| # | サーバー | パッケージ | 起動方法 | 検証 | `.mcp.json` |
|---|---------|-----------|---------|------|-------------|
| ① | 法令検索 | `hourei-mcp-server` (npm 1.0.6) | `npx -y hourei-mcp-server` | ✅ initialize 応答確認 | 登録済 (`hourei`) |
| ② | 税法 | `tax-law-mcp` (npm 0.5.4) | `npx -y tax-law-mcp` | ✅ initialize 応答確認 | 登録済 (`tax-law`) |
| ③ | 労務法 | `labor-law-mcp` (npm 0.2.1) | `npx -y labor-law-mcp` | ✅ initialize 応答確認 | 登録済 (`labor-law`) |
| ④ | 国会議事録 | `seiichi3141/kokkai-giji-mcp` (Docker) | `docker run -i --rm ...` | ⏸ 未検証 (docker daemon 未起動のため起動確認できず) | 登録済 (`kokkai-giji`) |
| ⑤ | 不動産・地理空間 | `mlit-dpf-mcp` (Python) | 国交省 API キー必須 | ⏸ 未検証 (キー未取得 + 起動コマンド未確定のため起動確認できず) | 未登録 (下記参照) |
| ⑥ | 金融分析 (Dexter JP) | EDINET DB (bun) | EDINET DB API キー必須 | ⏸ 未検証 (キー未取得 + 起動コマンド未確定のため起動確認できず) | 未登録 (下記参照) |

> 検証 = MCP `initialize` ハンドシェイクに正常応答したことを確認 (node v22 / npx 10.9)。**①②③ のみ実起動で検証済み**。④⑤⑥ は本セッションでは起動確認できていない (⑤⑥ の起動コマンドは下記の**推測値** — 各配布リポジトリの README で要確定)。
> ④ は remote/web 環境では docker daemon 未起動のため config のみ。docker 稼働マシンで別途検証のこと。

## セキュリティ / 信頼境界 (導入前に必読)

- **参照: [`docs/MCP_AUTH_SECURITY_PRINCIPLES.md`](MCP_AUTH_SECURITY_PRINCIPLES.md) (MCP 10 原則)。**
- ①②③ は `npx -y <package>` で **npm 上の第三者パッケージをバージョン固定なしに毎回取得して実行**する。パッケージ側の更新がレビューを挟まずそのまま走るため、本番運用ではバージョン固定を推奨:
  - `npx -y hourei-mcp-server@1.0.6` / `tax-law-mcp@0.5.4` / `labor-law-mcp@0.2.1`
- MCP サーバーの戻り値 (法令本文・議事録本文など外部取得テキスト) は**モデルの入力になる**。取得内容に含まれる指示文を**命令ではなくデータとして扱う** (prompt injection 耐性)。②③ サーバー自身も「一次情報 / 二次情報の区別」を強制する設計になっている。

## `.mcp.json` (①〜④ / この内容をプロジェクトルートに配置)

`.mcp.json` は本リポジトリで **gitignore 済** (`.gitignore` L62 / machine-local・secret 混入回避)。
clone 直後の手元には存在しないため、以下を**手動でプロジェクトルートに作成**すること (= 本ドキュメントが唯一の正本):

```json
{
  "mcpServers": {
    "hourei":    { "command": "npx",    "args": ["-y", "hourei-mcp-server"] },
    "tax-law":   { "command": "npx",    "args": ["-y", "tax-law-mcp"] },
    "labor-law": { "command": "npx",    "args": ["-y", "labor-law-mcp"] },
    "kokkai-giji": { "command": "docker", "args": ["run", "-i", "--rm", "seiichi3141/kokkai-giji-mcp"] }
  }
}
```

> 本番運用ではセキュリティ節のとおり `hourei-mcp-server@1.0.6` 等とバージョン固定を推奨。

## ① 法令検索 MCP

- e-Gov 法令 API に接続。法令名検索 / 条文取得 / 改正履歴。
- キー不要。`.mcp.json` の `hourei` として登録 (断片は上記「`.mcp.json` (①〜④)」節)。実起動で検証済み。

## ② 税法 MCP

- e-Gov + 国税庁の通達・裁決事例。24 主要税法 / 17 行政通達 / 1,950 裁決事例。
- ハルシネーション防止設計 (条文言及時は必ずツールで原文取得を強制)。
- キー不要。`.mcp.json` の `tax-law` として登録 (断片は上記節)。実起動で検証済み。

## ③ 労務法 MCP

- 45 労働関連法令 + 厚労省通達 (労基署・安全衛生含む)。②と同作者 / MIT。
- キー不要。`.mcp.json` の `labor-law` として登録 (断片は上記節)。実起動で検証済み。

## ④ 国会議事録 MCP

- 国立国会図書館 API。国会議事録の全文検索 + URL/PDF 取得。
- Docker イメージ pull が必要:

```bash
docker pull seiichi3141/kokkai-giji-mcp
```

- `.mcp.json` の `kokkai-giji` として登録 (`docker run -i --rm seiichi3141/kokkai-giji-mcp`)。
- docker daemon が動いているマシンでのみ起動可能。**本セッションでは daemon 未起動のため起動確認できていない** (docker 稼働環境で要検証)。イメージ最終更新 2026-01 (やや古い)。

## ⑤ 不動産・地理空間 MCP (mlit-dpf-mcp) — API キー要

- 国交省 公式。不動産情報ライブラリ API (地価・防災データ等)、18+ ツール。
- ⚠️ アルファ版 (「動作保証は行っておりません」と明記)。
- 前提: Python 3.10+ / 国交省 API キー (不動産情報ライブラリで発行)。

導入後、キーを環境変数に入れて `.mcp.json` に以下を追記:

```jsonc
// ⚠️ 以下の command/args は未検証の推測値。README で確定してから使うこと。
"mlit-dpf": {
  "command": "python",
  "args": ["-m", "mlit_dpf_mcp"],   // ← 推測。実パッケージの起動方法に合わせて要調整
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
// ⚠️ 以下の command/args は未検証の推測値。README で確定してから使うこと。
"dexter-jp": {
  "command": "bun",
  "args": ["run", "start"],   // ← 推測。実リポジトリの起動 script に合わせて要調整
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
