import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  invoiceSubscriptionId,
  subscriptionCurrentPeriodEnd,
} from "./stripe_api_compat.ts";

// fixture は実際の payload の入れ子をそのまま再現する。抜き出した 1 階層だけを
// 渡す fixture だと「その形を読める」ことしか確かめられず、本番の payload で
// パスが 1 段ずれていても緑のまま通ってしまう。

/** 2026-06-24.dahlia の invoice.payment_failed。basil で `subscription` は消えている。 */
const DAHLIA_INVOICE = {
  id: "in_1QxYzAIriTNCQL2dahlia",
  object: "invoice",
  customer: "cus_TestCustomer",
  status: "open",
  attempted: true,
  parent: {
    type: "subscription_details",
    quote_details: null,
    subscription_details: {
      subscription: "sub_1QxYzAIriTNCQL2dahlia",
      subscription_proration_date: null,
      metadata: { user_id: "user-123" },
    },
  },
};

/** 2020-03-02 の invoice。`parent` が存在しない。 */
const LEGACY_INVOICE = {
  id: "in_1QxYzAIriTNCQL2legacy",
  object: "invoice",
  customer: "cus_TestCustomer",
  status: "open",
  attempted: true,
  subscription: "sub_1QxYzAIriTNCQL2legacy",
};

/** 2026-06-24.dahlia の subscription。期間は item 側にある。 */
const DAHLIA_SUBSCRIPTION = {
  id: "sub_1QxYzAIriTNCQL2dahlia",
  object: "subscription",
  customer: "cus_TestCustomer",
  status: "active",
  cancel_at_period_end: false,
  latest_invoice: "in_1QxYzAIriTNCQL2dahlia",
  metadata: { user_id: "user-123", tier: "pro" },
  items: {
    object: "list",
    has_more: false,
    url: "/v1/subscription_items?subscription=sub_1QxYzAIriTNCQL2dahlia",
    data: [
      {
        id: "si_dahlia_pro",
        object: "subscription_item",
        current_period_start: 1774000000,
        current_period_end: 1776592000,
        price: { id: "price_pro_monthly", object: "price" },
      },
    ],
  },
};

/** 2020-03-02 の subscription。`items.data` はあるが item に期間が無い。 */
const LEGACY_SUBSCRIPTION = {
  id: "sub_1QxYzAIriTNCQL2legacy",
  object: "subscription",
  customer: "cus_TestCustomer",
  status: "active",
  cancel_at_period_end: false,
  latest_invoice: "in_1QxYzAIriTNCQL2legacy",
  metadata: { user_id: "user-123", tier: "pro" },
  current_period_start: 1774000000,
  current_period_end: 1776592000,
  items: {
    object: "list",
    has_more: false,
    data: [
      {
        id: "si_legacy_pro",
        object: "subscription_item",
        price: { id: "price_pro_monthly", object: "price" },
      },
    ],
  },
};

Deno.test("invoiceSubscriptionId reads the 2026-06-24.dahlia parent hash", () => {
  assertEquals(
    invoiceSubscriptionId(DAHLIA_INVOICE),
    "sub_1QxYzAIriTNCQL2dahlia",
  );
});

Deno.test("invoiceSubscriptionId still reads the pre-basil flat field", () => {
  assertEquals(
    invoiceSubscriptionId(LEGACY_INVOICE),
    "sub_1QxYzAIriTNCQL2legacy",
  );
});

Deno.test("invoiceSubscriptionId unwraps an expanded subscription object", () => {
  const expanded = {
    ...DAHLIA_INVOICE,
    parent: {
      type: "subscription_details",
      subscription_details: {
        subscription: {
          id: "sub_expanded",
          object: "subscription",
          status: "past_due",
        },
      },
    },
  };
  assertEquals(invoiceSubscriptionId(expanded), "sub_expanded");
});

Deno.test("invoiceSubscriptionId prefers the new path when both are present", () => {
  // アカウント既定バージョンを上げる過渡期に両方載った場合でも結果が揺れないこと。
  const both = { ...LEGACY_INVOICE, parent: DAHLIA_INVOICE.parent };
  assertEquals(invoiceSubscriptionId(both), "sub_1QxYzAIriTNCQL2dahlia");
});

Deno.test("invoiceSubscriptionId returns empty for a non-subscription invoice", () => {
  const quoteInvoice = {
    id: "in_quote",
    object: "invoice",
    customer: "cus_TestCustomer",
    parent: {
      type: "quote_details",
      quote_details: { quote: "qt_123" },
      subscription_details: null,
    },
  };
  assertEquals(invoiceSubscriptionId(quoteInvoice), "");
  assertEquals(invoiceSubscriptionId({ id: "in_oneoff", parent: null }), "");
  assertEquals(invoiceSubscriptionId({}), "");
});

Deno.test("subscriptionCurrentPeriodEnd reads the 2026-06-24.dahlia item period", () => {
  assertEquals(subscriptionCurrentPeriodEnd(DAHLIA_SUBSCRIPTION), 1776592000);
});

Deno.test("subscriptionCurrentPeriodEnd still reads the pre-basil flat field", () => {
  // 旧形は items.data が空振りするので、top-level へ落ちて同じ値を返す。
  assertEquals(subscriptionCurrentPeriodEnd(LEGACY_SUBSCRIPTION), 1776592000);
});

Deno.test("subscriptionCurrentPeriodEnd takes the earliest of mixed intervals", () => {
  // 「次回更新」として表示する値なので、次に請求が走る = 最も早い item を採る。
  const mixed = {
    ...DAHLIA_SUBSCRIPTION,
    items: {
      object: "list",
      has_more: false,
      data: [
        {
          id: "si_yearly",
          object: "subscription_item",
          current_period_end: 1805000000,
          price: { id: "price_pro_yearly", object: "price" },
        },
        {
          id: "si_monthly",
          object: "subscription_item",
          current_period_end: 1776592000,
          price: { id: "price_addon_monthly", object: "price" },
        },
      ],
    },
  };
  assertEquals(subscriptionCurrentPeriodEnd(mixed), 1776592000);
});

Deno.test("subscriptionCurrentPeriodEnd returns null when no period is available", () => {
  assertEquals(
    subscriptionCurrentPeriodEnd({
      id: "sub_incomplete",
      object: "subscription",
      items: { object: "list", data: [] },
    }),
    null,
  );
  assertEquals(subscriptionCurrentPeriodEnd({}), null);
  // 0 / 負値 / 非数値は「期間なし」として null に倒す (epoch 0 を 1970 年として
  // 書き込むと、UI に「次回更新 1970/01/01」が出る)。
  assertEquals(
    subscriptionCurrentPeriodEnd({ current_period_end: 0 }),
    null,
  );
  assertEquals(
    subscriptionCurrentPeriodEnd({ current_period_end: "not-a-number" }),
    null,
  );
});
