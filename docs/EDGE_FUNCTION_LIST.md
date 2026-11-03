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
| `enterprise-hub` | A/B テスト / アクセス制御 / その他企業機能統合 (= 旧 42 本 / HR・analytics・CI・AI-writing・CRM 等) |
| `app-hub` | アプリ基盤統合 (= 旧 17 本 / subscription・billing・email・gamification・calendar・kanban・chat・team-task・file-storage・expense・time-tracker・automation-workflows・webhook・api-rate-limiter 等) |
| `media-hub` | メディア統合 (= 旧 18 本 / video・audio・whiteboard・esign 等 + music-collaboration) |
| `social-commerce-hub` | SNS / EC 統合 (= 旧 26 本 / SNS・EC・payment・loyalty 等) |
| `lifestyle-hub` | ライフスタイル統合 (= 旧 29 本 / health・travel・IoT・notification 等) |
| `memory-search-hub` | BM25 + vector search (= 4 actions / part 115 PS#5 実装) |

> 旧 EF 本数は `deploy-prod.yml` 末尾の「Hub対応表」コメントより。`tools-hub` は 30 本。

## サポート系 EF

| Function | 用途 |
| --- | --- |
| `health-check` | インフラヘルスチェック |
| `resource-optimizer` | 認証ユーザーの習慣実績をRLS下で相関・パレート分析し、境界内の習慣だけをAIメンターまたは決定論フォールバックで提案する |

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

## 有償動画生成 EF (= 2026-08-20 追加)

| Function | 用途 |
| --- | --- |
| `video-generation-hub` | 認証必須の自社 text-to-video API。前払いクレジットを原子的に予約して自社GPUキューへ登録し、完成動画の1時間限定URLだけを利用者へ返す。外部の動画生成APIは呼び出さない。 |
| `video-worker-hub` | `VIDEO_WORKER_TOKEN` で認証した自社GPUワーカー専用API。ジョブの排他的リース、heartbeat、限定パスへの署名付きupload、出力検査、完了・再試行・失敗精算を担当する。service-role keyやモデル秘密情報をGPUホストへ渡さない。 |
| `video-commerce-hub` | ownerが固定承認したexact artifact/reviewだけを非公開`product-downloads`へクラウド内複製し、Stripe Product/Priceを冪等作成、非公開商品検証後に`/shop`を有効化する。失敗時は販売停止へrollbackし、原本は変更しない。 |

決済は `schedule-hub` の `billing.create_video_credit_checkout_session`、付与と全額返金時の回収は署名検証済み `stripe-webhook` が担当する。生成予約後は `VIDEO_WORKER_WAKE_TOKEN` で認証した自社Cloud Run controllerが固定のGCP GPU VMだけを起動し、起動不能なら未claimの予約を失敗確定してクレジットを即時返却する。Pro/Team の月額「無制限」には含めない。

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
> 正しいが action 名が旧 EF 名のまま**で、`hub_guidance()` が実在しない action を案内して
> いた (例: `core-hub` に `development-achievements` という action は無い)。
> `reply-support-request` は項目自体が欠落していた。#4404 で、実装を読んで確認できた
> ものだけを `VERIFIED_ACTIONS` に置き、未確認は推測を出さず「hub の switch を見ろ」と
> 案内する形に修正済み。**正は上表**。

### 消えた EF を叩いていた呼び出し元 5 件 (2026-07-29 / 修正 PR あり)

上表の移設は完了していたが、**旧 EF 名のまま実行される経路が 5 件残っていた**。
いずれも失敗が握り潰される作りで、CI もダッシュボードも緑のままだった
(本番 HTTP で 404 を実測)。

| 呼び出し元 | 叩いていた名前 | 症状 | 修正 |
| --- | --- | --- | --- |
| `.github/workflows/cs-check.yml` Step 5 | `/functions/v1/development-achievements` | Supabase 死活 probe が常に 404。判定は `>=500` / `000` / `403` のみなので **404 は健全と見なされ dead-green** | #4388 |
| `.github/workflows/feedback-issue-resolved.yml` | `/functions/v1/issue-auto-resolver` | Issue 解決記録が 404。`\|\| true` で無音 | #4388 |
| `.github/workflows/blog-publish.yml` Step 6 | `/functions/v1/schedule_task_runs` | **EF ですらなくテーブル名** (`/rest/v1/` が正)。他 10 workflow は正しく、ここだけ誤り。`-o /dev/null` + `\|\| true` で完全に無音 = 一度も記録されていない | #4388 |
| `lib/pages/viral_ad_generator_page.dart` `_postToX()` | `post-x-update` / `x-media-post` | 両分岐とも消えた EF。加えて `success` を見ておらず失敗でも「投稿完了」と表示 | #4388 |
| `supabase/functions/guitar-recording-studio/index.ts` | `/functions/v1/post-x-update` | 録音公開時の X 投稿が 404。`console.warn` で握り潰され呼び出し側は成功扱い | #4404 |

**probe 先を替えるだけでは直らない** — `health-check` は `status: "unhealthy"` でも
**HTTP 200 をハードコードで返す**。status コードだけ見る実装のままだと probe 先を
変えても dead-green が続くので、body の `status` と失敗した check 名まで読む必要がある。

**なぜ既存ガードで捕まらなかったか** — `audit_hub_migration_completeness.py`
(= `stale-ef-completeness-check.yml` の CI ゲート) には穴が 3 つあった。
上表 5 件のうち **1 件も検出できていなかった**。

1. **走査範囲** — `lib/` と `scripts/` のみで `.github/` と `supabase/functions/` を
   見ない。表の 1・2・3・5 は原理的に検出不可能。走査拡張子にも `.yml` が無かった。
2. **リテラル前提** — `invoke()` 検出が文字列リテラル前提で、
   `endpoint = '...'` → `invoke(endpoint, ...)` の**変数経由**を素通り (表の 4)。
3. **`DEAD_LIST` 自体が不完全** — `development-achievements` /
   `notify-feature-request` / `personal-dashboard` / `system-status` /
   `app-analytics-dashboard` が未掲載。**これが表 1 を見逃した直接の原因**。

#4404 で 3 つとも塞いだ。検出基準は「`DEAD_LIST` に載っているか」ではなく
**「`supabase/functions/` にディレクトリが実在するか」**= ファイルシステムの実態に
変えたので、手で維持する一覧の更新漏れがそのまま検出漏れにならない。

> 手で確認する場合は `git grep` で `functions/v1/<名前>` と `invoke(` の両方を見る。
> **`invoke(` はリテラルだけでなく変数経由も追う**こと。

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
