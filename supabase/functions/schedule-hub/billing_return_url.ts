// billing return URL の解決 (純ロジック / Deno API 非依存 → unit testable)
//
// Stripe checkout の success_url / cancel_url に使う return URL を検証する。
// billing.create_supporter_checkout_session は非ログイン公開 action のため、
// `body.return_url` を無検証で Stripe に渡すと **open-redirect** になる
// (攻撃者が checkout 後に任意の外部フィッシングサイトへ誘導可能)。
// host を allowlist で照合し、許可外・不正なら deployment fallback に落とす。

/// return URL の host が allowlist に含まれるか (大文字小文字無視・完全一致)。
export function isBillingHostAllowed(
  hostname: string,
  allowedHosts: readonly string[],
): boolean {
  const host = hostname.toLowerCase();
  return allowedHosts.some((h) => h.toLowerCase() === host);
}

/// deployment base URL の host + localhost + 追加許可 host から allowlist を作る。
export function billingAllowedHosts(
  base: string,
  extraHosts: readonly string[] = [],
): string[] {
  const hosts = new Set<string>(["localhost", "127.0.0.1"]);
  try {
    hosts.add(new URL(base).hostname.toLowerCase());
  } catch {
    // base が不正 URL でも localhost 群は残す。
  }
  for (const h of extraHosts) {
    const trimmed = h.trim().toLowerCase();
    if (trimmed) hosts.add(trimmed);
  }
  return [...hosts];
}

/// return URL を解決する。
/// - http/https かつ host が allowlist 内 → そのまま返す (path/query 温存)。
/// - それ以外 (別 host / javascript: 等の別 protocol / パース不能 / 空) →
///   base + fallbackPath に落とす。
export function resolveBillingReturnUrl(
  value: unknown,
  fallbackPath: string,
  opts: { base: string; allowedHosts: readonly string[] },
): string {
  const raw = typeof value === "string" ? value.trim() : "";
  if (raw) {
    try {
      const url = new URL(raw);
      const protocolOk = url.protocol === "https:" || url.protocol === "http:";
      if (protocolOk && isBillingHostAllowed(url.hostname, opts.allowedHosts)) {
        return url.toString();
      }
    } catch {
      // Fall through to the deployment fallback.
    }
  }
  return new URL(fallbackPath, opts.base).toString();
}
