export const LOCAL_BUSINESS_TARGET_ID = "fuchu-honmachi-1";
export const LOCAL_BUSINESS_OVERPASS_ENDPOINT =
  "https://overpass-api.de/api/interpreter";

export const FUCHU_HONMACHI_1_TARGET = {
  id: LOCAL_BUSINESS_TARGET_ID,
  areaName: "東京都府中市 本町1丁目",
  center: { latitude: 35.666471, longitude: 139.477994 },
  radiusMeters: 300,
} as const;

export const FUCHU_HONMACHI_1_OFFICIAL_AGGREGATE = {
  surveyName: "令和3年経済センサス－活動調査 町丁・大字別集計",
  surveyDate: "2021-06-01",
  areaName: FUCHU_HONMACHI_1_TARGET.areaName,
  totalEstablishments: 86,
  totalEmployees: 991,
  soleProprietorEstablishments: 20,
  soleProprietorEmployees: 79,
  sourceLabel: "政府統計の総合窓口 e-Stat",
  sourceUrl:
    "https://www.e-stat.go.jp/help/data-definition-information/about-recorded-data",
  disclosureNote:
    "町丁・大字別の集計値です。個々の事業所名や個人経営者名は公表されていません。",
} as const;

type JsonRecord = Record<string, unknown>;

export type PublicBusinessReference = {
  id: string;
  osmType: "node" | "way" | "relation";
  osmId: number;
  name: string;
  category: string;
  categoryCode: string;
  latitude: number;
  longitude: number;
  distanceMeters: number;
  address: string;
  ownershipStatus: "unknown";
  ownershipLabel: "経営形態未確認";
  sourceLabel: "OpenStreetMap";
  sourceUrl: string;
};

export type LocalBusinessReferencePayload = {
  success: true;
  target: typeof FUCHU_HONMACHI_1_TARGET;
  officialAggregate: typeof FUCHU_HONMACHI_1_OFFICIAL_AGGREGATE;
  publicReference: {
    businesses: PublicBusinessReference[];
    count: number;
    fetchedAt: string;
    sourceLabel: "OpenStreetMap via Overpass API";
    sourceUrl: "https://www.openstreetmap.org/copyright";
    license: "ODbL 1.0";
    coverageNote: string;
    ownershipNote: string;
    matchesOfficialAggregate: false;
  };
};

export type LocalBusinessReferenceActionResult = {
  status: number;
  body:
    | LocalBusinessReferencePayload
    | { success: false; error: "unsupported_target" }
    | { success: false; error: "public_reference_unavailable" };
};

export async function dispatchLocalBusinessReferenceAction(
  body: Record<string, unknown>,
  load: (
    options: { limit?: unknown },
  ) => Promise<LocalBusinessReferencePayload> = fetchLocalBusinessReferences,
): Promise<LocalBusinessReferenceActionResult> {
  const targetId = String(
    body.target_id ?? LOCAL_BUSINESS_TARGET_ID,
  ).trim();
  if (targetId !== LOCAL_BUSINESS_TARGET_ID) {
    return {
      status: 400,
      body: { success: false, error: "unsupported_target" },
    };
  }
  try {
    return {
      status: 200,
      body: await load({ limit: body.limit ?? 30 }),
    };
  } catch (_) {
    return {
      status: 502,
      body: { success: false, error: "public_reference_unavailable" },
    };
  }
}

function asRecord(value: unknown): JsonRecord {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as JsonRecord;
}

function finiteNumber(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function clampLimit(value: unknown): number {
  const parsed = Math.trunc(finiteNumber(value) ?? 30);
  return Math.min(Math.max(parsed, 1), 50);
}

function toRadians(value: number): number {
  return value * Math.PI / 180;
}

export function distanceMeters(
  latitude: number,
  longitude: number,
  center = FUCHU_HONMACHI_1_TARGET.center,
): number {
  const earthRadiusMeters = 6_371_000;
  const dLat = toRadians(latitude - center.latitude);
  const dLon = toRadians(longitude - center.longitude);
  const lat1 = toRadians(center.latitude);
  const lat2 = toRadians(latitude);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return earthRadiusMeters * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

const CATEGORY_LABELS: Record<string, string> = {
  "shop:bakery": "パン・菓子店",
  "shop:convenience": "コンビニエンスストア",
  "shop:hairdresser": "理美容店",
  "shop:supermarket": "スーパーマーケット",
  "shop:deli": "食品店",
  "shop:electronics": "電器店",
  "shop:bicycle": "自転車店",
  "shop:dry_cleaning": "クリーニング店",
  "office:estate_agent": "不動産業",
  "office:company": "事業所",
  "craft:photographer": "写真業",
  "amenity:restaurant": "飲食店",
  "amenity:cafe": "カフェ",
  "amenity:fast_food": "軽飲食店",
  "amenity:bar": "バー",
  "amenity:pub": "居酒屋・パブ",
  "amenity:clinic": "診療所",
  "amenity:dentist": "歯科診療所",
  "amenity:pharmacy": "薬局",
  "amenity:bank": "銀行",
  "amenity:post_office": "郵便局",
  "amenity:marketplace": "市場",
};

const EXCLUDED_NON_BUSINESS_CATEGORIES = new Set([
  "office:government",
  "office:religion",
  "office:political_party",
  "office:ngo",
  "office:association",
]);

function categoryCode(tags: JsonRecord): string | null {
  for (const key of ["shop", "office", "craft", "amenity"]) {
    const value = String(tags[key] ?? "").trim();
    if (value !== "") return `${key}:${value}`;
  }
  return null;
}

function categoryLabel(code: string): string {
  if (CATEGORY_LABELS[code]) return CATEGORY_LABELS[code];
  const [kind] = code.split(":", 1);
  if (kind === "shop") return "店舗";
  if (kind === "office") return "事業所";
  if (kind === "craft") return "技能・サービス業";
  return "施設・サービス";
}

function businessAddress(tags: JsonRecord): string {
  const full = String(tags["addr:full"] ?? "").trim();
  if (full !== "") return full;
  const parts = [
    tags["addr:province"],
    tags["addr:city"],
    tags["addr:suburb"],
    tags["addr:quarter"],
    tags["addr:neighbourhood"],
    tags["addr:street"],
    tags["addr:housenumber"],
  ].map((value) => String(value ?? "").trim()).filter(Boolean);
  return parts.length === 0 ? "住所情報はOSM未登録" : parts.join(" ");
}

function coordinates(element: JsonRecord): {
  latitude: number;
  longitude: number;
} | null {
  const center = asRecord(element.center);
  const latitude = finiteNumber(element.lat ?? center.lat);
  const longitude = finiteNumber(element.lon ?? center.lon);
  return latitude === null || longitude === null
    ? null
    : { latitude, longitude };
}

export function buildLocalBusinessOverpassQuery(): string {
  const { latitude, longitude } = FUCHU_HONMACHI_1_TARGET.center;
  const radius = FUCHU_HONMACHI_1_TARGET.radiusMeters;
  return `[out:json][timeout:25];
(
  nwr(around:${radius},${latitude},${longitude})["name"]["shop"];
  nwr(around:${radius},${latitude},${longitude})["name"]["office"];
  nwr(around:${radius},${latitude},${longitude})["name"]["craft"];
  nwr(around:${radius},${latitude},${longitude})["name"]["amenity"~"^(restaurant|cafe|fast_food|bar|pub|clinic|dentist|pharmacy|bank|post_office|marketplace)$"];
);
out center tags qt 100;`;
}

export function normalizeOpenStreetMapBusinesses(
  payload: unknown,
  limit: unknown = 30,
): PublicBusinessReference[] {
  const elements = asRecord(payload).elements;
  if (!Array.isArray(elements)) {
    throw new Error("overpass_response_missing_elements");
  }

  const seen = new Set<string>();
  const businesses: PublicBusinessReference[] = [];
  for (const rawElement of elements) {
    const element = asRecord(rawElement);
    const osmType = String(element.type ?? "");
    if (osmType !== "node" && osmType !== "way" && osmType !== "relation") {
      continue;
    }
    const osmId = finiteNumber(element.id);
    const tags = asRecord(element.tags);
    const name = String(tags.name ?? "").trim();
    const code = categoryCode(tags);
    const point = coordinates(element);
    if (
      osmId === null || name === "" || code === null || point === null ||
      EXCLUDED_NON_BUSINESS_CATEGORIES.has(code)
    ) {
      continue;
    }
    const distance = distanceMeters(point.latitude, point.longitude);
    if (distance > FUCHU_HONMACHI_1_TARGET.radiusMeters + 1) continue;
    const id = `${osmType}/${Math.trunc(osmId)}`;
    if (seen.has(id)) continue;
    seen.add(id);
    businesses.push({
      id,
      osmType,
      osmId: Math.trunc(osmId),
      name,
      category: categoryLabel(code),
      categoryCode: code,
      latitude: point.latitude,
      longitude: point.longitude,
      distanceMeters: Math.round(distance),
      address: businessAddress(tags),
      ownershipStatus: "unknown",
      ownershipLabel: "経営形態未確認",
      sourceLabel: "OpenStreetMap",
      sourceUrl: `https://www.openstreetmap.org/${osmType}/${
        Math.trunc(osmId)
      }`,
    });
  }

  businesses.sort((left, right) =>
    left.distanceMeters - right.distanceMeters ||
    left.name.localeCompare(right.name, "ja")
  );
  return businesses.slice(0, clampLimit(limit));
}

let cachedOverpassPayload: {
  value: unknown;
  fetchedAt: Date;
  expiresAt: number;
} | null = null;

export async function fetchLocalBusinessReferences(
  options: {
    limit?: unknown;
    fetcher?: typeof fetch;
    now?: () => Date;
  } = {},
): Promise<LocalBusinessReferencePayload> {
  const fetcher = options.fetcher ?? fetch;
  const now = options.now ?? (() => new Date());
  const currentTime = now();
  const hasFreshCache = cachedOverpassPayload?.expiresAt &&
      cachedOverpassPayload.expiresAt > currentTime.getTime()
    ? true
    : false;
  let rawPayload = hasFreshCache ? cachedOverpassPayload!.value : null;
  let fetchedAt = hasFreshCache
    ? cachedOverpassPayload!.fetchedAt
    : currentTime;

  if (rawPayload === null) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 28_000);
    try {
      const response = await fetcher(LOCAL_BUSINESS_OVERPASS_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
          "User-Agent":
            "my_web_app-local-business-map/0.1 (https://my-web-app-b67f4.web.app)",
        },
        body: new URLSearchParams({ data: buildLocalBusinessOverpassQuery() }),
        signal: controller.signal,
      });
      if (!response.ok) {
        throw new Error(`overpass_http_${response.status}`);
      }
      rawPayload = await response.json();
      cachedOverpassPayload = {
        value: rawPayload,
        fetchedAt: currentTime,
        expiresAt: currentTime.getTime() + 15 * 60 * 1000,
      };
      fetchedAt = currentTime;
    } finally {
      clearTimeout(timer);
    }
  }

  const businesses = normalizeOpenStreetMapBusinesses(
    rawPayload,
    options.limit,
  );
  return {
    success: true,
    target: FUCHU_HONMACHI_1_TARGET,
    officialAggregate: FUCHU_HONMACHI_1_OFFICIAL_AGGREGATE,
    publicReference: {
      businesses,
      count: businesses.length,
      fetchedAt: fetchedAt.toISOString(),
      sourceLabel: "OpenStreetMap via Overpass API",
      sourceUrl: "https://www.openstreetmap.org/copyright",
      license: "ODbL 1.0",
      coverageNote:
        "本町一丁目のOSM中心点から300m以内に公開登録された名称付き施設の参考一覧です。町丁境界と完全には一致しません。",
      ownershipNote:
        "経済センサスの個票とは照合していません。個人経営かどうかを推測・判定しません。",
      matchesOfficialAggregate: false,
    },
  };
}
