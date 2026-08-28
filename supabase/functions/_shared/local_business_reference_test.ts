import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildLocalBusinessOverpassQuery,
  dispatchLocalBusinessReferenceAction,
  fetchLocalBusinessReferences,
  FUCHU_HONMACHI_1_TARGET,
  normalizeOpenStreetMapBusinesses,
} from "./local_business_reference.ts";

Deno.test("Overpass query is fixed to the approved read-only target", () => {
  const query = buildLocalBusinessOverpassQuery();

  assertStringIncludes(query, "around:300,35.666471,139.477994");
  assertStringIncludes(query, '["name"]["shop"]');
  assertStringIncludes(query, "out center tags qt 100");
  assertEquals(query.includes("{{"), false);
});

Deno.test("OSM rows are normalized, distance sorted, and ownership stays unknown", () => {
  const { latitude, longitude } = FUCHU_HONMACHI_1_TARGET.center;
  const rows = normalizeOpenStreetMapBusinesses({
    elements: [
      {
        type: "node",
        id: 2,
        lat: latitude + 0.001,
        lon: longitude,
        tags: { name: "遠い店", shop: "bakery" },
      },
      {
        type: "node",
        id: 101,
        lat: latitude,
        lon: longitude,
        tags: { name: "行政施設", office: "government" },
      },
      {
        type: "way",
        id: 1,
        center: { lat: latitude, lon: longitude },
        tags: {
          name: "本町商店",
          shop: "deli",
          "addr:city": "府中市",
          "addr:quarter": "本町一丁目",
        },
      },
      {
        type: "node",
        id: 99,
        lat: latitude + 0.01,
        lon: longitude,
        tags: { name: "範囲外", shop: "convenience" },
      },
      { type: "node", id: 100, lat: latitude, lon: longitude, tags: {} },
    ],
  }, 10);

  assertEquals(rows.length, 2);
  assertEquals(rows[0].name, "本町商店");
  assertEquals(rows[0].category, "食品店");
  assertEquals(rows[0].ownershipStatus, "unknown");
  assertEquals(rows[0].ownershipLabel, "経営形態未確認");
  assertStringIncludes(rows[0].address, "本町一丁目");
  assertStringIncludes(rows[0].sourceUrl, "/way/1");
  assert(rows[1].distanceMeters > rows[0].distanceMeters);
});

Deno.test("response keeps the official aggregate separate from public rows", async () => {
  const { latitude, longitude } = FUCHU_HONMACHI_1_TARGET.center;
  const fakeFetch = (() =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          elements: [{
            type: "node",
            id: 7,
            lat: latitude,
            lon: longitude,
            tags: { name: "公開店舗", shop: "bakery" },
          }],
        }),
        { status: 200 },
      ),
    )) as typeof fetch;

  const payload = await fetchLocalBusinessReferences({
    fetcher: fakeFetch,
    now: () => new Date("2026-08-14T12:00:00Z"),
  });

  assertEquals(payload.officialAggregate.soleProprietorEstablishments, 20);
  assertEquals(payload.publicReference.count, 1);
  assertEquals(payload.publicReference.matchesOfficialAggregate, false);
  assertStringIncludes(payload.publicReference.ownershipNote, "推測");
  assertEquals(payload.publicReference.fetchedAt, "2026-08-14T12:00:00.000Z");
});

Deno.test("OSM limit is bounded to fifty records", () => {
  const { latitude, longitude } = FUCHU_HONMACHI_1_TARGET.center;
  const rows = normalizeOpenStreetMapBusinesses({
    elements: Array.from({ length: 60 }, (_, index) => ({
      type: "node",
      id: index + 1,
      lat: latitude,
      lon: longitude,
      tags: { name: `店${index + 1}`, shop: "convenience" },
    })),
  }, 999);

  assertEquals(rows.length, 50);
});

Deno.test("public hub action validates target and forwards limit", async () => {
  let receivedLimit: unknown;
  const valid = await dispatchLocalBusinessReferenceAction(
    { target_id: "fuchu-honmachi-1", limit: 12 },
    async ({ limit }) => {
      receivedLimit = limit;
      return await fetchLocalBusinessReferences({
        fetcher: (() =>
          Promise.resolve(
            new Response(JSON.stringify({ elements: [] }), { status: 200 }),
          )) as typeof fetch,
      });
    },
  );
  assertEquals(valid.status, 200);
  assertEquals(valid.body.success, true);
  assertEquals(receivedLimit, 12);

  const invalid = await dispatchLocalBusinessReferenceAction({
    target_id: "another-area",
  });
  assertEquals(invalid, {
    status: 400,
    body: { success: false, error: "unsupported_target" },
  });
});

Deno.test("public hub action maps upstream failure without leaking details", async () => {
  const result = await dispatchLocalBusinessReferenceAction(
    {},
    () => Promise.reject(new Error("sensitive upstream detail")),
  );
  assertEquals(result, {
    status: 502,
    body: { success: false, error: "public_reference_unavailable" },
  });
});
