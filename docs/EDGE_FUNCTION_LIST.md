# Supabase Edge Function 一覧

> Win版#132 part 133 (2026-05-05): 旧 CLAUDE.md L427-447 を移行 (= Karpathy 80 行 KPI 達成).
> 主要 EF のみ. 全件は `supabase/functions/` ディレクトリ参照.
>
> **2026-07-29 実在照合**: 本ファイルが EF として載せていた 8 本が既にディレクトリ非存在
> だったため、[統合済み旧 EF の hub action 対応表](#統合済み旧-ef-の-hub-action-対応表)
> へ移設した。**この表に載っている名前は EF ではない — `/functions/v1/<名前>` を叩くと 404 になる。**
> 照合時点の実在 EF は 25 本 (`git ls-tree --name-only origin/main supabase/functions/`
> から `_shared` / `deno.json` / `deno.lock` を除いた数)。

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
| `health-check` | インフラヘルスチェック |

サポートチケットと機能リクエスト通知は EF 単体ではなく hub action に統合済み
(= `admin-hub` `support.list` / `support.reply`, `core-hub` `notify.feature_request`)。
下の[対応表](#統合済み旧-ef-の-hub-action-対応表)を参照。

## ホーム / dashboard 系

| Function | 用途 |
| --- | --- |
| `get-home-dashboard` | ホーム画面統合データ |
| `growth-weekly-digest` | 週次グロース指標 |
| `autonomous-ops` | OMOCHA WORKS 自律オペレーションコンソール実データ (GitHub Actions run → カンバン/KPI 変換 / owner 限定 / 30s cache / `GH_ACTIONS_READ_TOKEN`)。詳細 [`AUTONOMOUS_OPS_CONSOLE.md`](AUTONOMOUS_OPS_CONSOLE.md) |

## 買い切り販売系 EF (= 2026-07-28 追加)

| Function | 用途 |
| --- | --- |
| `shop-checkout` | 買い切り商品の Stripe Checkout セッション作成 (関数内 `auth.getUser()` で認証) |
| `shop-download` | 購入済みユーザーへの成果物ダウンロード URL 発行 |

> この 2 本は `deploy-prod.yml` の明示リストに載っている。新規 EF をそこへ足し忘れると
> migration だけ本番へ入り CI は緑のまま半着地する ([`AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md))。

## 統合済み旧 EF の hub action 対応表

EF-CAP-50 に従い hub へ吸収された EF。**左列は EF 名ではなく履歴上の名前**で、
`supabase/functions/<左列>` は存在しない。呼び出しは右の hub + action で行う。
action 名は旧 EF 名とは異なり、hub 内はドット区切りに統一されている。

| 旧 EF 名 | 現 hub | action | 実装 |
| --- | --- | --- | --- |
| `get-support-tickets` | `admin-hub` | `support.list` | 未クローズの `hub_data` (source=`support_ticket`) を最大 50 件 |
| `reply-support-request` | `admin-hub` | `support.reply` | `reply` / `new_status` でチケット更新 (既定 `resolved`) |
| `notify-feature-request` | `core-hub` | `notify.feature_request` | 機能リクエスト更新通知メール (Resend / `RESEND_API_KEY`) |
| `development-achievements` | `core-hub` | `achievements.list` / `achievements.add` | 旧 EF の GET / ADD にそれぞれ対応 (`development_achievements` テーブル) |
| `get-admin-users` | `admin-hub` | `users.list` | `auth.admin.listUsers` (1 ページ 100 件) |
| `get-growth-roadmap-progress` | `growth-hub` | `roadmap.progress` | 進捗バーデータ (短中長期) |
| `get-competitor-features` | `admin-hub` | `competitor.list` | `competitor_features` テーブル |
| `post-x-update` | `schedule-hub` | `x.post` | X (Twitter) 自動投稿 (`@kanta13jp1`) / `dryRun` 対応。媒体付きは `x.post_with_media` |

> ⚠️ `scripts/audit_hub_migration_completeness.py` の `HUB_ACTIONS` は **hub の割り当ては
> 正しいが action 名が旧 EF 名のまま**で、`hub_guidance()` は実在しない action を案内する
> (例: `core-hub` に `development-achievements` という action は無い)。同表に
> `reply-support-request` の項目自体が欠落している。**正は上表**。

### 🔴 未修正: 消えた EF を今も叩いている呼び出し元 (2026-07-29 時点)

上表の移設は完了しているが、以下は**旧 EF 名のまま実行される経路**が残っている。
いずれも失敗が握り潰されるため CI もダッシュボードも緑のままになる。

| 呼び出し元 | 叩いている名前 | 症状 |
| --- | --- | --- |
| `.github/workflows/cs-check.yml` Step 5 | `/functions/v1/development-achievements` | Supabase 死活 probe が常に 404。判定は `>=500` / `000` / `403` のみなので **404 は健全と見なされ dead-green** |
| `supabase/functions/guitar-recording-studio/index.ts` | `/functions/v1/post-x-update` | 録音公開時の X 投稿が 404。`console.warn` で握り潰され呼び出し側は成功扱い |
| `lib/pages/viral_ad_generator_page.dart` `_postToX()` | `post-x-update` / `x-media-post` | 両分岐とも消えた EF。`invoke(endpoint, ...)` と**変数経由**のため後述の監査が検出できない |

**なぜ既存ガードで捕まらないか** — `audit_hub_migration_completeness.py` は
(1) 走査対象が `lib/` と `scripts/` のみで `.github/` と `supabase/functions/` を見ない、
(2) `invoke()` の検出が**文字列リテラル前提**の正規表現なので変数経由の呼び出しを素通りする。
新しい stale 参照を足さないためには、この 2 つの穴を塞ぐか、`git grep` で
`functions/v1/<名前>` と `invoke(` の両方を人手で確認する。

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

## 関連

- [`docs/DIRECTORY_STRUCTURE.md`](DIRECTORY_STRUCTURE.md) — リポジトリ全体構成
- [`docs/AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md) — EF 設計 7 原則
- [`docs/SCHEDULE_TASKS.md`](SCHEDULE_TASKS.md) — EF を呼ぶ cron
- [`CLAUDE.md`](../CLAUDE.md) — pointer hub
