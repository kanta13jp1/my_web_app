// schedule-hub action 認可レベル (純ロジック / Deno API 非依存 → unit testable)
//
// 3 レベル:
// - public: 認証不要 (read-only or 公開 endpoint)。書き込み系を足す前に
//   service_role 化を検討すること (anon key は Web アプリ同梱 = 実質公開)。
// - service_role: Bearer === SERVICE_ROLE_KEY 必須。オーナー資格情報
//   (QIITA_ACCESS_TOKEN / DEVTO_API_KEY / X API / NOTION_TOKEN) での投稿や
//   hub_data / wbs_tasks への system 書き込みを行う action はここ。
// - user: ログイン user JWT (or service role)。

export type ActionAuthLevel = "public" | "service_role" | "user";

// 認証不要 action。
// billing.create_supporter_checkout_session は非ログイン支援者導線
// (subscription_billing_page は未ログインで到達可能) のため public 維持:
// handler は任意の user JWT を自己購入除外の証跡にだけ使う。金額はサーバ側
// env 固定 / attribution metadata は 160 字切詰のみ Stripe metadata へ透過。
export const PUBLIC_ACTIONS: readonly string[] = [
  "health.check",
  "blog.recent_posted", // Win版#132 part 124: tech-blog-tracker page 用 public read
  "billing.create_supporter_checkout_session",
  "maintenance.list_active",
];

// SERVICE_ROLE_KEY Bearer 必須の書き込み系 action。
// 呼び出し元は GHA workflow / ops script のみ — 全て SERVICE_ROLE_KEY を送る:
// - blog.create / blog.auto_publish: blog-publish.yml / blog-batch-publish.yml
// - blog.backfill_from_apis: blog-backfill-from-apis.yml
// - x.post_with_media: post-x-with-media.yml
// - notion.sync_wbs: notion-sync.yml / issue-to-wbs.yml (Notion API 書き込み)
// - notion.preflight_wbs: scripts/release_readiness_gate.py (Notion schema 読取)
// - notion.sync_roadmap / notion.sync_memory_index: notion-sync.yml
// - notion.fix_wbs_all_instances: 手動 ops のみ (リポジトリ内呼び出しなし)
// - wbs.unblock_dependents: wbs-ai-review.yml (wbs_tasks status 更新)
// - reminders.study: ai-university-reminder.yml / daily-report.yml
//   (app_notifications insert / handler 内 service-role チェックも維持)
// anon key・ログイン user JWT では 401 (匿名 signup JWT でも通せない)。
export const SERVICE_ROLE_ONLY_ACTIONS: readonly string[] = [
  "billing.get_stripe_account_readiness",
  "blog.auto_publish",
  "blog.create",
  "blog.backfill_from_apis",
  "x.post_with_media",
  "notion.sync_wbs",
  "notion.preflight_wbs",
  "notion.sync_roadmap",
  "notion.sync_memory_index",
  "notion.fix_wbs_all_instances",
  "wbs.unblock_dependents",
  "reminders.study",
];

// digest.run は listed どちらにも無い = user レベル (要ログイン user JWT or
// service role)。呼び出し元は daily-report.yml (SERVICE_ROLE_KEY) と
// admin_analytics_page (session 必須 / user JWT) の 2 系統のみ。

export function requiredAuthLevel(action: string): ActionAuthLevel {
  if (SERVICE_ROLE_ONLY_ACTIONS.includes(action)) return "service_role";
  if (PUBLIC_ACTIONS.includes(action)) return "public";
  return "user";
}
