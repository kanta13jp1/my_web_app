import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildExtractiveResearchFallback,
  buildResearchCitationContext,
  canonicalResearchUrl,
  chunkResearchMarkdown,
  ensureCitationFooter,
  fetchPublicResearchDocument,
  htmlToResearchMarkdown,
  isPrivateNetworkHost,
  normalizePublicResearchUrl,
  normalizeResearchCitations,
} from "./company_research.ts";

Deno.test("research URLs reject private networks and unsafe schemes", () => {
  for (
    const host of [
      "localhost",
      "127.0.0.1",
      "10.2.3.4",
      "169.254.1.1",
      "::1",
      "fd00::1",
      "::ffff:7f00:1",
      "0:0:0:0:0:ffff:7f00:1",
      "64:ff9b::7f00:1",
      "ff02::1",
    ]
  ) {
    assertEquals(isPrivateNetworkHost(host), true);
  }
  assertThrows(() => normalizePublicResearchUrl("file:///etc/passwd"));
  assertThrows(() =>
    normalizePublicResearchUrl("http://user:pass@example.com")
  );
  assertThrows(() => normalizePublicResearchUrl("http://localhost/admin"));
  assertThrows(() =>
    normalizePublicResearchUrl("http://[::ffff:127.0.0.1]/admin")
  );
  assertThrows(() => normalizePublicResearchUrl("https://example.com:8443/a"));
  assertEquals(
    canonicalResearchUrl("HTTPS://Example.com:443/a?utm_source=x&b=2&a=1#top"),
    "https://example.com/a?a=1&b=2",
  );
});

Deno.test("structured HTML extraction removes scripts and keeps readable sections", () => {
  const result = htmlToResearchMarkdown(`
    <html><head><title>Market facts</title><script>steal()</script></head>
    <body><nav>Skip me</nav><main>
      <h1>Pricing</h1><p>The paid plan is $20 each month.</p>
      <ul><li>Includes exports</li><li>Includes support</li></ul>
    </main></body></html>
  `);
  assertEquals(result.title, "Market facts");
  assertStringIncludes(result.markdown, "# Pricing");
  assertStringIncludes(result.markdown, "- Includes exports");
  assertEquals(result.markdown.includes("steal"), false);
  assertEquals(result.markdown.includes("Skip me"), false);
});

Deno.test("markdown chunks retain citation locations and bounded content", () => {
  const chunks = chunkResearchMarkdown(
    `# Market\n\n${"Demand signal. ".repeat(90)}\n\n## Pricing\n\n${
      "Price evidence. ".repeat(90)
    }`,
    500,
  );
  assertEquals(chunks.length > 2, true);
  assertEquals(chunks.every((chunk) => chunk.content.length <= 500), true);
  assertEquals(chunks[0].location.startsWith("paragraphs "), true);
  assertEquals(chunks.some((chunk) => chunk.heading === "Pricing"), true);
});

Deno.test("citations are deduplicated and appended deterministically", () => {
  const citations = normalizeResearchCitations([
    {
      source_id: "source-1",
      source_url: "https://example.com/pricing",
      title: "Pricing",
      heading: "Pro plan",
      location: "paragraphs 2-3",
      content: "The pro plan costs $20.",
      score: 0.8,
    },
    {
      source_id: "source-1",
      source_url: "https://example.com/pricing",
      title: "Pricing",
      heading: "Pro plan",
      location: "paragraphs 2-3",
      content: "duplicate",
      score: 0.7,
    },
  ]);
  assertEquals(citations.length, 1);
  assertStringIncludes(buildResearchCitationContext(citations), "[1] Pricing");
  assertStringIncludes(
    ensureCitationFooter("Decision [1]", citations),
    "Sources",
  );
  assertStringIncludes(
    buildExtractiveResearchFallback("Review pricing", citations),
    "extractive evidence fallback",
  );
});

Deno.test("fetch rejects redirects into private networks before the second request", async () => {
  const calls: string[] = [];
  const fakeFetch = (
    input: string | URL | Request,
  ): Promise<Response> => {
    const url = input instanceof Request ? input.url : input.toString();
    calls.push(url);
    if (url.startsWith("https://cloudflare-dns.com/")) {
      return Promise.resolve(
        Response.json({ Answer: [{ type: 1, data: "93.184.216.34" }] }),
      );
    }
    return Promise.resolve(
      new Response(null, {
        status: 302,
        headers: { location: "http://127.0.0.1/private" },
      }),
    );
  };
  await assertRejects(
    () => fetchPublicResearchDocument("https://example.com/start", fakeFetch),
    Error,
    "Private or local network",
  );
  assertEquals(calls.some((url) => url.includes("127.0.0.1")), false);
});
