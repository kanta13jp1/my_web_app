export const DEFAULT_LAYOUT_ALERT_THRESHOLD = 3;

export type SelectorAlertStatus =
  | "healthy"
  | "degraded"
  | "layout_change_alert";

export const SELECTOR_ALERT_LABELS = {
  healthy: "正常稼働",
  degraded: "一部セレクタ失敗",
  layout_change_alert: "レイアウト変更疑いアラート",
} as const satisfies Record<SelectorAlertStatus, string>;

export interface DomainSelectorConfig {
  domain: string;
  currency: string;
  priceSelectors: string[];
  titleSelectors: string[];
  availabilitySelectors: string[];
  failureAlertThreshold: number;
  consecutiveFailures: number;
  updatedAt: string;
}

export interface LayoutChangeAlert {
  domain: string;
  targetUrl: string;
  status: SelectorAlertStatus;
  statusLabel: string;
  consecutiveFailures: number;
  threshold: number;
  triedSelectors: string[];
  detectedAt: string;
  message: string;
}

export interface SelectorExtractionResult {
  ok: boolean;
  domain: string;
  matchedPriceSelector: string | null;
  matchedTitleSelector: string | null;
  rawPriceText: string | null;
  numericPrice: number | null;
  currency: string | null;
  title: string | null;
  alert: LayoutChangeAlert | null;
  consecutiveFailures: number;
}

export interface SelectorRegistryStore {
  getConfig(domain: string): Promise<DomainSelectorConfig | null>;
  upsertConfig(config: DomainSelectorConfig): Promise<void>;
  listConfigs(): Promise<DomainSelectorConfig[]>;
}

const DEFAULT_DOMAIN_CONFIGS: DomainSelectorConfig[] = [
  {
    domain: "amazon.co.jp",
    currency: "JPY",
    priceSelectors: [
      "#corePriceDisplay_desktop_feature_div .a-price-whole",
      "#priceblock_ourprice",
      ".a-price .a-offscreen",
    ],
    titleSelectors: ["#productTitle", "h1#title"],
    availabilitySelectors: ["#availability span", "#outOfStock"],
    failureAlertThreshold: DEFAULT_LAYOUT_ALERT_THRESHOLD,
    consecutiveFailures: 0,
    updatedAt: "2026-11-26T00:00:00Z",
  },
  {
    domain: "flipkart.com",
    currency: "INR",
    priceSelectors: [
      "div.Nx9bqj",
      "div._30jeq3",
      "[data-testid=\"product-price\"]",
    ],
    titleSelectors: ["span.VU-ZEz", "h1.yhB1nd"],
    availabilitySelectors: ["div._16FRp0"],
    failureAlertThreshold: DEFAULT_LAYOUT_ALERT_THRESHOLD,
    consecutiveFailures: 0,
    updatedAt: "2026-11-26T00:00:00Z",
  },
];

export class InMemorySelectorRegistryStore implements SelectorRegistryStore {
  private readonly configs = new Map<string, DomainSelectorConfig>();

  constructor(initialConfigs: DomainSelectorConfig[] = DEFAULT_DOMAIN_CONFIGS) {
    for (const cfg of initialConfigs) {
      this.configs.set(normalizeDomain(cfg.domain), {
        ...cfg,
        domain: normalizeDomain(cfg.domain),
        priceSelectors: [...cfg.priceSelectors],
        titleSelectors: [...cfg.titleSelectors],
        availabilitySelectors: [...cfg.availabilitySelectors],
      });
    }
  }

  getConfig(domain: string): Promise<DomainSelectorConfig | null> {
    const key = normalizeDomain(domain);
    const exact = this.configs.get(key);
    if (exact) return Promise.resolve(exact);
    for (const [registered, cfg] of this.configs.entries()) {
      if (key === registered || key.endsWith(`.${registered}`)) {
        return Promise.resolve(cfg);
      }
    }
    return Promise.resolve(null);
  }

  upsertConfig(config: DomainSelectorConfig): Promise<void> {
    const key = normalizeDomain(config.domain);
    this.configs.set(key, {
      ...config,
      domain: key,
      priceSelectors: [...config.priceSelectors],
      titleSelectors: [...config.titleSelectors],
      availabilitySelectors: [...config.availabilitySelectors],
    });
    return Promise.resolve();
  }

  listConfigs(): Promise<DomainSelectorConfig[]> {
    return Promise.resolve([...this.configs.values()]);
  }
}

export function normalizeDomain(input: string): string {
  const cleaned = input.trim().toLowerCase().replace(/^www\./, "");
  return cleaned;
}

export function extractDomainFromUrl(targetUrl: string): string | null {
  try {
    const parsed = new URL(targetUrl);
    return normalizeDomain(parsed.hostname);
  } catch {
    return null;
  }
}

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function stripHtmlTags(raw: string): string {
  return raw
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function matchSingleSelectorPart(
  html: string,
  selectorPart: string,
): string | null {
  const part = selectorPart.trim();
  if (!part) return null;

  const attrMatch = part.match(/^\[([A-Za-z0-9_-]+)=["']([^"']+)["']\]$/);
  if (attrMatch) {
    const attrName = escapeRegex(attrMatch[1]);
    const attrVal = escapeRegex(attrMatch[2]);
    const re = new RegExp(
      `<([A-Za-z0-9-]+)\\b[^>]*\\b${attrName}\\s*=\\s*` +
        `["']${attrVal}["'][^>]*>([\\s\\S]*?)</\\1>`,
      "i",
    );
    const m = html.match(re);
    return m ? stripHtmlTags(m[2]) || null : null;
  }

  const idMatch = part.match(/^(?:[A-Za-z0-9-]+)?#([A-Za-z0-9_-]+)$/);
  if (idMatch) {
    const idVal = escapeRegex(idMatch[1]);
    const re = new RegExp(
      `<([A-Za-z0-9-]+)\\b[^>]*\\bid\\s*=\\s*` +
        `["']${idVal}["'][^>]*>([\\s\\S]*?)</\\1>`,
      "i",
    );
    const m = html.match(re);
    return m ? stripHtmlTags(m[2]) || null : null;
  }

  const classMatch = part.match(/^(?:[A-Za-z0-9-]+)?\.([A-Za-z0-9_-]+)$/);
  if (classMatch) {
    const clsVal = escapeRegex(classMatch[1]);
    const re = new RegExp(
      `<([A-Za-z0-9-]+)\\b[^>]*\\bclass\\s*=\\s*` +
        `["'][^"']*\\b${clsVal}\\b[^"']*["'][^>]*>([\\s\\S]*?)</\\1>`,
      "i",
    );
    const m = html.match(re);
    return m ? stripHtmlTags(m[2]) || null : null;
  }

  return null;
}

export function querySelectorText(
  html: string,
  selector: string,
): string | null {
  const parts = selector.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return null;
  // For descendant selectors (`#parent .child`), try full chain or leaf part.
  const leaf = parts[parts.length - 1];
  if (parts.length === 1) {
    return matchSingleSelectorPart(html, leaf);
  }
  const parentText = matchSingleSelectorPart(html, parts[0]);
  if (parentText !== null) {
    return matchSingleSelectorPart(html, leaf) ?? parentText;
  }
  return matchSingleSelectorPart(html, leaf);
}

export function parseNumericPrice(raw: string | null): number | null {
  if (!raw) return null;
  const normalized = raw.replace(/,/g, "");
  const match = normalized.match(/(\d+(?:\.\d+)?)/);
  if (!match) return null;
  const parsed = Number(match[1]);
  return Number.isFinite(parsed) ? parsed : null;
}

export async function extractWithDynamicSelectors(params: {
  targetUrl: string;
  html: string;
  store: SelectorRegistryStore;
  now?: () => Date;
}): Promise<SelectorExtractionResult> {
  const nowIso = (params.now ?? (() => new Date()))().toISOString();
  const domain = extractDomainFromUrl(params.targetUrl) ?? "";
  const config = domain ? await params.store.getConfig(domain) : null;

  if (!config) {
    return {
      ok: false,
      domain,
      matchedPriceSelector: null,
      matchedTitleSelector: null,
      rawPriceText: null,
      numericPrice: null,
      currency: null,
      title: null,
      alert: null,
      consecutiveFailures: 0,
    };
  }

  let matchedPriceSelector: string | null = null;
  let rawPriceText: string | null = null;
  let numericPrice: number | null = null;

  for (const selector of config.priceSelectors) {
    const candidate = querySelectorText(params.html, selector);
    const parsed = parseNumericPrice(candidate);
    if (candidate && parsed !== null) {
      matchedPriceSelector = selector;
      rawPriceText = candidate;
      numericPrice = parsed;
      break;
    }
  }

  let matchedTitleSelector: string | null = null;
  let title: string | null = null;
  for (const selector of config.titleSelectors) {
    const candidate = querySelectorText(params.html, selector);
    if (candidate) {
      matchedTitleSelector = selector;
      title = candidate;
      break;
    }
  }

  if (numericPrice !== null) {
    const resetConfig: DomainSelectorConfig = {
      ...config,
      consecutiveFailures: 0,
      updatedAt: nowIso,
    };
    await params.store.upsertConfig(resetConfig);
    return {
      ok: true,
      domain: config.domain,
      matchedPriceSelector,
      matchedTitleSelector,
      rawPriceText,
      numericPrice,
      currency: config.currency,
      title,
      alert: null,
      consecutiveFailures: 0,
    };
  }

  const nextFailures = config.consecutiveFailures + 1;
  const threshold = Math.max(1, config.failureAlertThreshold);
  await params.store.upsertConfig({
    ...config,
    consecutiveFailures: nextFailures,
    updatedAt: nowIso,
  });

  const alertTriggered = nextFailures >= threshold;
  const status: SelectorAlertStatus = alertTriggered
    ? "layout_change_alert"
    : "degraded";
  const alert: LayoutChangeAlert | null = alertTriggered
    ? {
      domain: config.domain,
      targetUrl: params.targetUrl,
      status,
      statusLabel: SELECTOR_ALERT_LABELS[status],
      consecutiveFailures: nextFailures,
      threshold,
      triedSelectors: [...config.priceSelectors],
      detectedAt: nowIso,
      message: `${config.domain} で価格抽出が ${nextFailures} 回連続失敗。` +
        "レイアウト変更の可能性があります。",
    }
    : null;

  return {
    ok: false,
    domain: config.domain,
    matchedPriceSelector: null,
    matchedTitleSelector,
    rawPriceText: null,
    numericPrice: null,
    currency: config.currency,
    title,
    alert,
    consecutiveFailures: nextFailures,
  };
}
