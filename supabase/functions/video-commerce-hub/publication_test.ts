import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  safeErrorCode,
  sha256Hex,
  validatePublicationPacket,
} from "./publication.ts";

const ARTIFACT_ID = "11111111-1111-4111-8111-111111111111";
const REVIEW_ID = "22222222-2222-4222-8222-222222222222";

function packet(overrides: Record<string, unknown> = {}) {
  return {
    artifact_id: ARTIFACT_ID,
    review_id: REVIEW_ID,
    validity_hours: 168,
    product_id: "ai-office-broll-v1",
    title: "AI office B-roll",
    summary: "Commercial office video material.",
    description: "A five-second first-party GPU-generated office clip.",
    price_jpy: 500,
    currency: "jpy",
    territory: "worldwide",
    license_summary:
      "Commercial use and editing allowed; standalone redistribution prohibited.",
    publication_channel: "/shop",
    rollback_action: "deactivate_listing",
    rights_confirmed: true,
    privacy_confirmed: true,
    fictional_person_confirmed: true,
    no_third_party_logos_confirmed: true,
    no_unlicensed_material_confirmed: true,
    ...overrides,
  };
}

Deno.test("publication packet fixes all commercial and clearance fields", () => {
  const result = validatePublicationPacket(packet());
  assertEquals(result.ok, true);
  if (!result.ok) return;
  assertEquals(result.value.artifactId, ARTIFACT_ID);
  assertEquals(result.value.productId, "ai-office-broll-v1");
  assertEquals(result.value.priceJpy, 500);
  assertEquals(result.value.validityHours, 168);
});

Deno.test("publication packet rejects missing rights confirmation", () => {
  assertEquals(
    validatePublicationPacket(packet({ privacy_confirmed: false })),
    { ok: false, code: "publication_confirmations_required" },
  );
});

Deno.test("publication packet rejects mutable channel and currency choices", () => {
  assertEquals(
    validatePublicationPacket(packet({ publication_channel: "/market" })),
    { ok: false, code: "unsupported_publication_policy" },
  );
  assertEquals(
    validatePublicationPacket(packet({ currency: "usd" })),
    { ok: false, code: "unsupported_publication_policy" },
  );
});

Deno.test("publication helpers produce stable hashes and safe error codes", async () => {
  assertEquals(
    await sha256Hex(new Blob(["video"])),
    "0cab1c9617404faf2b24e221e189ca5945813e14d3f766345b09ca13bbe28ffc",
  );
  assertEquals(
    safeErrorCode(new Error("Stripe API failed: 500")),
    "stripe_api_failed_500",
  );
});
