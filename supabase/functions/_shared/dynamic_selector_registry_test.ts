import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  extractWithDynamicSelectors,
  InMemorySelectorRegistryStore,
} from "./dynamic_selector_registry.ts";

Deno.test(
  "extractWithDynamicSelectors resolves domain fallback and dynamic config",
  async () => {
    const store = new InMemorySelectorRegistryStore();
    const html = `
      <html>
        <body>
          <h1 id="title">Noise Cancelling Headphones</h1>
          <span id="priceblock_ourprice">¥24,800</span>
        </body>
      </html>
    `;

    const res = await extractWithDynamicSelectors({
      targetUrl: "https://www.amazon.co.jp/dp/B000EXAMPLE",
      html,
      store,
    });

    assertEquals(res.ok, true);
    assertEquals(res.domain, "amazon.co.jp");
    assertEquals(res.matchedPriceSelector, "#priceblock_ourprice");
    assertEquals(res.numericPrice, 24800);
    assertEquals(res.currency, "JPY");
    assertEquals(res.title, "Noise Cancelling Headphones");
    assertEquals(res.alert, null);

    // Dynamic update without code redeploy.
    await store.upsertConfig({
      domain: "flipkart.com",
      currency: "INR",
      priceSelectors: ["[data-testid=\"fk-new-price\"]"],
      titleSelectors: ["span.VU-ZEz"],
      availabilitySelectors: [],
      failureAlertThreshold: 2,
      consecutiveFailures: 0,
      updatedAt: "2026-11-26T05:00:00Z",
    });

    const fkRes = await extractWithDynamicSelectors({
      targetUrl: "https://www.flipkart.com/item/p/123",
      html: `<span data-testid="fk-new-price">₹1,999</span>`,
      store,
    });
    assertEquals(fkRes.ok, true);
    assertEquals(fkRes.numericPrice, 1999);
    assertEquals(fkRes.currency, "INR");
  },
);

Deno.test(
  "extractWithDynamicSelectors emits alert on consecutive failures and resets",
  async () => {
    const store = new InMemorySelectorRegistryStore();
    const brokenHtml = "<html><body><div>Layout changed</div></body></html>";

    const r1 = await extractWithDynamicSelectors({
      targetUrl: "https://www.amazon.co.jp/dp/B0001",
      html: brokenHtml,
      store,
    });
    assertEquals(r1.ok, false);
    assertEquals(r1.consecutiveFailures, 1);
    assertEquals(r1.alert, null);

    const r2 = await extractWithDynamicSelectors({
      targetUrl: "https://www.amazon.co.jp/dp/B0001",
      html: brokenHtml,
      store,
    });
    assertEquals(r2.consecutiveFailures, 2);
    assertEquals(r2.alert, null);

    const r3 = await extractWithDynamicSelectors({
      targetUrl: "https://www.amazon.co.jp/dp/B0001",
      html: brokenHtml,
      store,
    });
    assertEquals(r3.consecutiveFailures, 3);
    assertEquals(r3.alert?.status, "layout_change_alert");
    assertStringIncludes(r3.alert?.message ?? "", "amazon.co.jp");

    // Recovery resets consecutiveFailures to 0.
    const recovered = await extractWithDynamicSelectors({
      targetUrl: "https://www.amazon.co.jp/dp/B0001",
      html: `<span id="priceblock_ourprice">¥3,200</span>`,
      store,
    });
    assertEquals(recovered.ok, true);
    assertEquals(recovered.consecutiveFailures, 0);
    assertEquals(recovered.alert, null);
  },
);
