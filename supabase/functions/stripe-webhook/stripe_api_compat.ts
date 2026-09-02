/**
 * Stripe API バージョン間で移動したフィールドを吸収する層 (2026-07-29 追加)。
 *
 * 背景: HexCiv 買い切り販売を有効化するため、webhook endpoint を
 * 2020-03-02 から 2026-06-24.dahlia で作り直した。その間の
 * **2025-03-31.basil** で、サブスク周りの 2 フィールドが削除されている
 * (deprecated ではなく removed):
 *
 *   - `invoice.subscription`
 *       → `invoice.parent.subscription_details.subscription`
 *   - `subscription.current_period_end`
 *       → `subscription.items.data[].current_period_end`
 *
 * なぜ新旧どちらも読むのか: 「削除済みなら新形だけ読めばよい」ように見えるが、
 * この EF には **2 つの API バージョンが同時に流れ込む**。
 *
 *   - webhook event の payload → endpoint に固定した 2026-06-24.dahlia (新形)
 *   - `stripeGet()` の戻り値   → `Stripe-Version` ヘッダを送っていないため
 *                                アカウント既定バージョン (= 旧形のまま)
 *
 * `upsertSubscriptionFromStripe()` はこの両方から呼ばれる (checkout 経由は
 * `stripeGet()`、`customer.subscription.*` は event payload) ので、片方の形しか
 * 読まない実装は必ずもう片方で静かに null を書き込む。アカウント既定バージョンを
 * 引き上げた後も、この層はそのまま無害に効き続ける。
 */

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

/**
 * expandable な参照フィールドから ID を取り出す。
 *
 * Stripe の参照フィールドは expand 指定で文字列 ID から object に化けるため、
 * 文字列だけを想定すると展開されていた場合に黙って空文字になる。
 */
export function referenceId(value: unknown): string {
  if (typeof value === "string") return value.trim();
  const id = asRecord(value)?.id;
  return typeof id === "string" ? id.trim() : "";
}

function epochSeconds(value: unknown): number | null {
  const seconds = typeof value === "string" ? Number(value.trim()) : value;
  return typeof seconds === "number" && Number.isFinite(seconds) && seconds > 0
    ? Math.trunc(seconds)
    : null;
}

/**
 * invoice が属する subscription の ID を返す (見つからなければ空文字)。
 *
 * `parent.type === 'subscription_details'` の確認はあえてしない。もう一方の
 * parent 種別である `quote_details` に `subscription` フィールドは存在せず、
 * hash が埋まっていること自体が subscription 由来である十分条件になるため。
 * type を必須にすると、将来 parent 種別が増えたときに読めなくなる側に倒れる。
 */
export function invoiceSubscriptionId(
  invoice: Record<string, unknown>,
): string {
  // 2025-03-31.basil 以降。
  const details = asRecord(asRecord(invoice.parent)?.subscription_details);
  const fromParent = referenceId(details?.subscription);
  if (fromParent) return fromParent;

  // 2025-03-31.basil 未満。
  return referenceId(invoice.subscription);
}

/**
 * subscription の現在の請求期間の終了時刻を epoch 秒で返す。
 *
 * 新形では期間が item 単位になったため、単一の値へ畳む必要がある。ここでは
 * **最小値** を採る: この値は UI で「次回更新」として表示されるので
 * (`lib/pages/subscription_billing_page.dart`)、次に請求が走るのは最も早く
 * 期間が終わる item だから。max を採ると、既に課金された後の日付を「次回」
 * として見せてしまう。単一 price のサブスクでは全 item が同値なので一致する。
 */
export function subscriptionCurrentPeriodEnd(
  subscription: Record<string, unknown>,
): number | null {
  const items = asRecord(subscription.items)?.data;
  if (Array.isArray(items)) {
    const ends: number[] = [];
    for (const item of items) {
      const end = epochSeconds(asRecord(item)?.current_period_end);
      if (end !== null) ends.push(end);
    }
    // 注: `items` はページングされるリストなので、1 ページに収まらない数の item を
    // 持つサブスクでは見えている範囲の最小値になる。現行商品は単一 price のため
    // 影響しない。該当するプランを増やすときはここを API 再取得に変えること。
    if (ends.length > 0) return Math.min(...ends);
  }

  // 2025-03-31.basil 未満。旧形でも `items.data` 自体は存在するが、item 側に
  // 期間フィールドが無いため上のループは空振りしてここへ落ちる。
  return epochSeconds(subscription.current_period_end);
}
