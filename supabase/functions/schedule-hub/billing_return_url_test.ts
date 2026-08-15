import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  billingAllowedHosts,
  isBillingHostAllowed,
  resolveBillingReturnUrl,
} from "./billing_return_url.ts";

const BASE = "https://my-web-app-b67f4.web.app";
const HOSTS = billingAllowedHosts(BASE);

Deno.test("allowlist は base host + localhost 群を含む", () => {
  assertEquals(HOSTS.includes("my-web-app-b67f4.web.app"), true);
  assertEquals(HOSTS.includes("localhost"), true);
  assertEquals(HOSTS.includes("127.0.0.1"), true);
});

Deno.test("追加許可 host は env csv から取り込む (空白・空要素は無視)", () => {
  const hosts = billingAllowedHosts(BASE, [" staging.example.com ", "", "  "]);
  assertEquals(hosts.includes("staging.example.com"), true);
});

Deno.test("host 照合は大文字小文字を無視した完全一致", () => {
  assertEquals(isBillingHostAllowed("My-Web-App-B67F4.Web.App", HOSTS), true);
  assertEquals(isBillingHostAllowed("evil.example.com", HOSTS), false);
  // 部分一致・サブドメイン偽装は許可しない。
  assertEquals(
    isBillingHostAllowed("my-web-app-b67f4.web.app.evil.com", HOSTS),
    false,
  );
});

Deno.test("許可 host の return_url は path/query 温存でそのまま通す", () => {
  const url = resolveBillingReturnUrl(
    "https://my-web-app-b67f4.web.app/subscription-billing?ref=x",
    "/subscription-billing",
    { base: BASE, allowedHosts: HOSTS },
  );
  assertEquals(
    url,
    "https://my-web-app-b67f4.web.app/subscription-billing?ref=x",
  );
});

Deno.test("localhost の return_url も許可 (dev)", () => {
  const url = resolveBillingReturnUrl(
    "http://localhost:3000/subscription-billing",
    "/subscription-billing",
    { base: BASE, allowedHosts: HOSTS },
  );
  assertEquals(url, "http://localhost:3000/subscription-billing");
});

Deno.test("許可外 host は deployment fallback に落とす (open-redirect 遮断)", () => {
  const url = resolveBillingReturnUrl(
    "https://evil.example.com/phish",
    "/subscription-billing",
    { base: BASE, allowedHosts: HOSTS },
  );
  assertEquals(url, "https://my-web-app-b67f4.web.app/subscription-billing");
});

Deno.test("javascript: など http/https 以外の protocol は fallback", () => {
  const url = resolveBillingReturnUrl(
    "javascript:alert(1)",
    "/subscription-billing",
    { base: BASE, allowedHosts: HOSTS },
  );
  assertEquals(url, "https://my-web-app-b67f4.web.app/subscription-billing");
});

Deno.test("空文字・null・パース不能は fallback", () => {
  const opts = { base: BASE, allowedHosts: HOSTS };
  const expected = "https://my-web-app-b67f4.web.app/subscription-billing";
  assertEquals(
    resolveBillingReturnUrl("", "/subscription-billing", opts),
    expected,
  );
  assertEquals(
    resolveBillingReturnUrl(null, "/subscription-billing", opts),
    expected,
  );
  assertEquals(
    resolveBillingReturnUrl("not a url", "/subscription-billing", opts),
    expected,
  );
});
