import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { verifyStripeEvent } from "./stripe_signature.ts";

const SECRET = "whsec_test_secret";
const NOW_MS = 1_800_000_000_000;
const NOW_SECONDS = Math.floor(NOW_MS / 1000);

async function hmacSha256Hex(message: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(message),
  );
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function signatureHeader(
  payload: string,
  timestamp: number,
): Promise<string> {
  const signature = await hmacSha256Hex(`${timestamp}.${payload}`);
  return `t=${timestamp},v1=${signature}`;
}

Deno.test("accepts a valid recent Stripe signature", async () => {
  const payload = JSON.stringify({ id: "evt_valid", type: "test.event" });
  const header = await signatureHeader(payload, NOW_SECONDS - 60);

  const event = await verifyStripeEvent(payload, header, SECRET, {
    nowMs: NOW_MS,
  });

  assertEquals(event.id, "evt_valid");
});

Deno.test("rejects a valid signature with a stale timestamp", async () => {
  const payload = JSON.stringify({ id: "evt_stale" });
  const header = await signatureHeader(payload, NOW_SECONDS - 301);

  await assertRejects(
    () => verifyStripeEvent(payload, header, SECRET, { nowMs: NOW_MS }),
    Error,
    "signature timestamp outside tolerance",
  );
});

Deno.test("rejects a recent payload with the wrong signature", async () => {
  const payload = JSON.stringify({ id: "evt_tampered" });
  const header = `t=${NOW_SECONDS},v1=${"0".repeat(64)}`;

  await assertRejects(
    () => verifyStripeEvent(payload, header, SECRET, { nowMs: NOW_MS }),
    Error,
    "invalid signature",
  );
});
