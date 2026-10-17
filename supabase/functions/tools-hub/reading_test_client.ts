// Test-only synthetic credentials and PostgREST adapter; never imported by index.ts.
import { createClient } from "npm:@supabase/supabase-js@2";

export async function readingTestClient(
  role = "service_role",
  subject?: string,
) {
  const url = Deno.env.get("READING_TEST_DATABASE_URL")!;
  const secret = Deno.env.get("READING_TEST_JWT_SECRET")!;
  const encode = (value: unknown) =>
    btoa(JSON.stringify(value)).replace(/=/g, "").replace(/\+/g, "-").replace(
      /\//g,
      "_",
    );
  const header = encode({ alg: "HS256", typ: "JWT" });
  const payload = encode({
    role,
    sub: subject,
    exp: Math.floor(Date.now() / 1000) + 3600,
  });
  const content = `${header}.${payload}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(content),
  );
  const suffix = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const token = `${content}.${suffix}`;
  return createClient(url, token, {
    global: {
      fetch: (input, init) => {
        const target = new URL(
          typeof input === "string"
            ? input
            : input instanceof URL
            ? input.href
            : input.url,
        );
        target.pathname = target.pathname.replace(/^\/rest\/v1/, "");
        return fetch(target, init);
      },
    },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
