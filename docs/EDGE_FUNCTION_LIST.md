# Supabase Edge Function 一覧

> Win版#132 part 133 (2026-05-05): 旧 CLAUDE.md L427-447 を移行 (= Karpathy 80 行 KPI 達成).
> 主要 EF のみ. 全件は `supabase/functions/` ディレクトリ参照.

## 主要 hub EF (= 多 action 統合)

| Function | 用途 |
| --- | --- |
| `core-hub` | コアUI・メモ・通知統合。公開メモ AI 向け API `memo.public.view` / `memo.public.list` / `memo.public.search` / `memo.public.related` (= 認証不要 GET・HEAD・POST / format=html\|json\|md / JSON は summary・markdown・tags 付き / SPA を読めない ChatGPT 等の AI・クローラー向け / 日次回帰 = public-memo-smoke.yml) |
| `tools-hub` | 個人生産性ツール統合 (= WBS / Issue / digest / agent_tool_policy 等) + **自分API** (= Notion Developer Platform 対抗 / part 133 WEB版 2026-07-12): 管理系 `jibunapi.key.create\|list\|revoke` / `jibunapi.worker.register\|list\|update\|delete` (Supabase JWT 認証) + 外部公開系 `api.me` / `api.notes.list\|create` / `api.tasks.list` / `api.achievements.list` / `api.workers.list\|invoke` (= `jibun_sk_` API キー Bearer 認証 / sha256 保存・スコープ制・rate limit 60分2000日・SSRF ガード・HMAC署名 Worker 呼び出し / user_api_keys・user_agent_workers・user_api_audit_log テーブル) |
| `schedule-hub` (`digest.run`) | Schedule 用日次メトリクス API + blog auto_publish + blog.recent_posted (= part 124) + blog.backfill_from_apis |
| `growth-hub` | グロース指標 / share track / command analyze (= part 112 EF 移行) |
| `admin-hub` | 競合可用性チェック (`competitor.check`) ほか管理者向け統合 |
| `ai-hub` | AI 機能統合 (= ai-assistant / daily-judgment / ai-writing-assistant / customer-feedback) |
| `enterprise-hub` | A/B テスト / アクセス制御 / その他企業機能統合 |
| `memory-search-hub` | BM25 + vector search (= 4 actions / part 115 PS#5 実装) |

## サポート系 EF

| Function | 用途 |
| --- | --- |
| `get-support-tickets` | 未返信チケット + FAQ 一覧 (Schedule 用) |
| `reply-support-request` | チケット返信・エスカレーション |
| `notify-feature-request` | 機能リクエスト更新通知メール |
| `health-check` | インフラヘルスチェック |

## ホーム / dashboard 系

| Function | 用途 |
| --- | --- |
| `get-home-dashboard` | ホーム画面統合データ |
| `growth-weekly-digest` | 週次グロース指標 |
| `development-achievements` | 開発実績一覧 |
| `get-admin-users` | 管理者用ユーザー一覧 |
| `get-growth-roadmap-progress` | 進捗バーデータ (1900+ 競合 + 短中長期) |
| `get-competitor-features` | 競合機能比較データ |
| `autonomous-ops` | OMOCHA WORKS 自律オペレーションコンソール実データ (GitHub Actions run → カンバン/KPI 変換 / owner 限定 / 30s cache / `GH_ACTIONS_READ_TOKEN`)。詳細 [`AUTONOMOUS_OPS_CONSOLE.md`](AUTONOMOUS_OPS_CONSOLE.md) |

## SNS / 配信系

| Function | 用途 |
| --- | --- |
| `post-x-update` | X (Twitter) 自動投稿 (`@kanta13jp1`) |

## 設計原則

- **EF-FIRST** (inject-rules.txt rule): 複雑ロジックは Flutter widget ではなく EF に置く
- **EF-CAP-50**: deploy-prod の EF 数は 50 本以下に維持. 超過時は hub 統合優先
- **deny-by-default** (AI_DEV_PRINCIPLES.md #2): EF 新 action は明示許可リストでホワイトリスト管理
- **trace_id + 5 秒超検出** (AI_DEV_PRINCIPLES.md #3): 各 step に trace_id
- **認証情報の env 名は連鎖で受ける**: 手順書とコードで名前が食い違うため、
  `Deno.env.get("A") ?? Deno.env.get("B")` の形で複数名を許容する
  (実例: `GITHUB_PAT ?? GITHUB_TOKEN ?? GH_TOKEN` / `FAL_KEY ?? FAL_API_KEY`)

### env 名ズレの監査手順

EF secret の未設定は**サイレント劣化**を起こす。多くの EF は「キーが無ければ機能を
落として続行」する設計なので、**呼び出し自体は成功したまま結果だけ静かに欠ける**。
2026-07-25 の実障害では、値は 2026-04-18 から `FAL_API_KEY` として存在したのに
コードが `FAL_KEY` しか読まず、AIシェアの動画が丸一日欠落していた
(X 投稿は成功し続けていたため気づけなかった)。

**注意**: docs の「✅ 設定済」は **GitHub Actions secret** を指していることがある。
これは Supabase EF secret とは**別ストア**で、片方の設定は他方を一切保証しない。

```bash
supabase secrets list --project-ref smmkxxavexumewbfaqpy
```

`secrets list` は**値ではなく名前と SHA256 ダイジェスト**を返すので、秘密を晒さずに
監査できる。使い方は 2 つ:

1. **同一値が別名で登録されていないか** — ダイジェストが一致する 2 名前があれば、
   同じキーが二重管理されている (今回 `FAL_KEY` と `FAL_API_KEY` が
   `103feae23d7db9…` で一致し、名前ズレだと値を見ずに確定できた)
2. **コードが読む名前が実在するか** — EF の `Deno.env.get("...")` を抽出して
   上のリストと突き合わせる。アルファベット順なので、隣接エントリを見れば
   不在を確定できる (`FAL_API_KEY` の次が `FISH_AUDIO_API_KEY` → `FAL_KEY` は不在)

修正後の検証は**エラー文言の変化**で見る。`not configured` から
provider 側の応答 (残高不足など) に変われば、キーは到達して認証は通っている。
「まだ動かない」は「直っていない」を意味しない — 段階の違うブロッカーへ
進んだだけのことがある。

### 「読まれているが未登録」= 障害とは限らない

上の差分は**候補**であって障害リストではない。**意図的にオフの任意機能**と
**設定したつもりで壊れている機能**は差分だけでは区別できず、以下 3 点を
揃えて初めて判定できる (2026-07-29 に認証情報 12 件を判定して確立)。

| # | 確認事項 | 外すとどう間違えるか |
| --- | --- | --- |
| (a) | **未設定時の分岐** — 全停止 / 既定値で縮退 / 完全に無害 | 縮退設計済みを障害と誤検知する。`AIRTABLE_API_KEY` 未設定は `configured:false` → Supabase competitors へ自動フォールバック = 無害 |
| (b) | **その action の呼び出し元が実在するか** | allowlist に名前があるだけで**永久に実行されない** action を「壊れている」と数える。判定は `git grep '<action名>' -- lib scripts .github supabase/migrations` |
| (c) | **同時に必要な他の env** | ゲートしている変数を見落とす。`VIRAL_VIDEO_PROVIDER_API_KEY` は `VIRAL_VIDEO_PROVIDER_URL` が空の時点で fetch 自体が走らないので単独登録は無意味 |

落とし穴:

- **別名 action に注意**。UI が呼ぶのは `legal-assistant.harvey.complete` なので
  `legal.harvey` だけを grep すると呼び出し元ゼロと誤判定する。(b) は
  **EF 側の `case` 全部**を候補に grep する。
- **語幹が近い = 名前ズレ ではない**。`SLACK_BOT_TOKEN` (Bot OAuth トークン) と
  登録済 `SLACK_WEBHOOK_URL` (Incoming Webhook URL)、`X_BEARER_TOKEN` (OAuth 2.0) と
  登録済 `X_API_KEY`/`X_ACCESS_TOKEN` (OAuth 1.0a) は**別の認証方式**で代替不可。
  ダイジェスト一致 (上の使い方 1) が取れない限り名前ズレと断定しない。
- **UI 導線の有無まで見る**。資格情報が無いのに UI にボタン/選択肢が実在する場合、
  鍵を足すのではなく**導線を隠す**のが正しい修正のことがある。
- **未設定時に 200 を返す経路は latent dead green**。`core-hub:discord.notify` は
  未設定時 `skipped` かつ HTTP 200 (現状 呼び出し元ゼロで実害なし / 将来 cron から
  呼ぶと「成功したのに届かない」に化ける)。
- **鍵を足しても直らないことがある**。`LINE_NOTIFY_TOKEN` が叩く `notify-api.line.me` は
  **2025-03-31 に LINE Notify 自体がサービス終了**し 2025-04-01 以降 全 API が利用不可
  ([公式告知](https://notify-bot.line.me/closing-announce) / 代替は Messaging API)。

## 関連

- [`docs/DIRECTORY_STRUCTURE.md`](DIRECTORY_STRUCTURE.md) — リポジトリ全体構成
- [`docs/AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md) — EF 設計 7 原則
- [`docs/SCHEDULE_TASKS.md`](SCHEDULE_TASKS.md) — EF を呼ぶ cron
- [`CLAUDE.md`](../CLAUDE.md) — pointer hub
