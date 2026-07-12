// schedule-hub action 認可レベル (純ロジック / Deno API 非依存 → unit testable)
//
// 3 レベル:
// - public: 認証不要 (read-only or 公開 endpoint)。書き込み系を足す前に
//   service_role 化を検討すること (anon key は Web アプリ同梱 = 実質公開)。
// - service_role: Bearer === SERVICE_ROLE_KEY 必須。オーナー資格情報
//   (QIITA_ACCESS_TOKEN / DEVTO_API_KEY / X API) での投稿や hub_data への
//   system 書き込みを行う action はここ。
// - user: ログイン user JWT (or service role)。

export type ActionAuthLevel = "public" | "service_role" | "user";

// 認証不要 action。
export const PUBLIC_ACTIONS: readonly string[] = [
  "digest.run",
  "health.check",
  "blog.recent_posted", // Win版#132 part 124: tech-blog-tracker page 用 public read
  "reminders.study",
  "notion.sync_wbs",
  "notion.preflight_wbs",
  "notion.sync_roadmap",
  "notion.sync_memory_index",
  "notion.fix_wbs_all_instances",
  "wbs.unblock_dependents",
  "billing.create_supporter_checkout_session",
  "maintenance.list_active",
];

// SERVICE_ROLE_KEY Bearer 必須の書き込み系 action。
// 呼び出し元は GHA workflow のみ: blog-publish.yml (blog.create /
// blog.auto_publish) / blog-batch-publish.yml → scripts/batch_publish.py
// (blog.auto_publish) / blog-backfill-from-apis.yml (blog.backfill_from_apis) /
// post-x-with-media.yml (x.post_with_media) — 全て SERVICE_ROLE_KEY を送る。
// anon key・ログイン user JWT では 401 (匿名 signup JWT でも通せない)。
export const SERVICE_ROLE_ONLY_ACTIONS: readonly string[] = [
  "blog.auto_publish",
  "blog.create",
  "blog.backfill_from_apis",
  "x.post_with_media",
];

export function requiredAuthLevel(action: string): ActionAuthLevel {
  if (SERVICE_ROLE_ONLY_ACTIONS.includes(action)) return "service_role";
  if (PUBLIC_ACTIONS.includes(action)) return "public";
  return "user";
}
