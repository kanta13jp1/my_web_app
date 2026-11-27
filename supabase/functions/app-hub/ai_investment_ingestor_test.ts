import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  collectPublicInvestmentFeeds,
  inferQuarterFromIso,
  normalizeInvestmentBatch,
  normalizeInvestmentRecord,
  parseRssOrAtomFeed,
  renderCollectionMarkdown,
  sanitizeHttpUrl,
} from "./ai_investment_ingestor.ts";

Deno.test(
  "normalizeInvestmentRecord forces needs_verification on forged flags",
  () => {
    const record = normalizeInvestmentRecord({
      company_name: "Example LLM Lab",
      round_stage: "Series B",
      amount_usd: 42_500_000,
      announced_at: "2026-05-12T09:00:00Z",
      source_name: "Official Press",
      source_url: "https://example.com/news/series-b",
      investors: "Alpha VC, Beta Ventures",
      verification_status: "verified",
      verified: true,
      is_verified: true,
      verified_by: "attacker",
      verified_at: "2026-05-12T00:00:00Z",
    }, { ingestedAt: "2026-05-13T00:00:00Z" });

    assertEquals(record.company_name, "Example LLM Lab");
    assertEquals(record.quarter, "2026-Q2");
    assertEquals(record.round_stage, "Series B");
    assertEquals(record.amount_usd_millions, 42.5);
    assertEquals(record.amount_display, "$42.5M");
    assertEquals(record.investors, ["Alpha VC", "Beta Ventures"]);
    assertEquals(record.raw_format, "structured_json");
    assertEquals(record.verification_status, "needs_verification");
    assertEquals(record.verification_label, "要検証");
    assertEquals(record.requires_manual_verification, true);
    assertEquals(record.verified_at, null);
    assertEquals(record.verified_by, null);
    assertEquals(record.verification_note, "");
  },
);

Deno.test(
  "normalizeInvestmentRecord handles RSS aliases and unsafe URLs",
  () => {
    const record = normalizeInvestmentRecord({
      title: "Nova Compute raises strategic funding for inference cluster",
      link: "javascript:alert(1)",
      pubDate: "Fri, 15 May 2026 12:00:00 GMT",
      publisher: "Tech Feed",
      amount_text: "非公開（要確認）",
    }, { ingestedAt: "2026-05-15T13:00:00Z" });

    assertEquals(record.company_name, "Nova Compute");
    assertEquals(record.quarter, "2026-Q2");
    assertEquals(record.round_stage, "Strategic");
    assertEquals(record.source_url, "");
    assertEquals(record.amount_usd_millions, null);
    assertEquals(record.amount_display, "非公開（要確認）");
    assertEquals(record.raw_format, "rss_item");
    assertEquals(record.verification_status, "needs_verification");
  },
);

Deno.test(
  "parseRssOrAtomFeed filters items and forces needs_verification",
  () => {
    const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel>
  <item>
    <title><![CDATA[VectorFlow raises $15M Seed round for enterprise RAG]]></title>
    <link>https://example.org/vectorflow-seed</link>
    <pubDate>Tue, 28 Apr 2026 10:00:00 GMT</pubDate>
    <description>Seed investment led by Cloud Partners.</description>
  </item>
  <item>
    <title>Weekly UI Icon Refresh Notes</title>
    <link>https://example.org/ui-notes</link>
    <pubDate>Wed, 29 Apr 2026 10:00:00 GMT</pubDate>
    <description>Minor button spacing polish.</description>
  </item>
</channel></rss>`;

    const parsed = parseRssOrAtomFeed(xml, {
      sourceName: "Sample RSS",
      filterInvestmentRelevant: true,
      ingestedAt: "2026-05-01T00:00:00Z",
    });
    assertEquals(parsed.length, 1);
    assertEquals(parsed[0].company_name, "VectorFlow");
    assertEquals(parsed[0].quarter, "2026-Q2");
    assertEquals(parsed[0].verification_status, "needs_verification");
    assertEquals(parsed[0].verification_label, "要検証");
  },
);

Deno.test(
  "normalizeInvestmentBatch isolates invalid rows without failing valid rows",
  () => {
    const res = normalizeInvestmentBatch([
      null,
      { org: "" },
      { org: "ValidAI", round: "Series A", date: "2026-06-01T00:00:00Z" },
    ], { ingestedAt: "2026-06-02T00:00:00Z" });

    assertEquals(res.records.length, 1);
    assertEquals(res.errors.length, 2);
    assertEquals(res.records[0].company_name, "ValidAI");
    assertEquals(res.records[0].quarter, "2026-Q2");
    assertEquals(res.records[0].verification_status, "needs_verification");
  },
);

Deno.test(
  "collectPublicInvestmentFeeds fails soft per source and renders report",
  async () => {
    const mockFetch: typeof fetch = (input) => {
      const url = typeof input === "string" ? input : input.toString();
      if (url.includes("ok-feed")) {
        const xml = `<feed><entry>
          <title>OpenModel secures $30M Series A investment</title>
          <link href="https://example.net/openmodel" />
          <updated>2026-04-20T00:00:00Z</updated>
          <summary>Series A round announced.</summary>
        </entry></feed>`;
        return Promise.resolve(new Response(xml, { status: 200 }));
      }
      return Promise.resolve(new Response("Unavailable", { status: 503 }));
    };

    const report = await collectPublicInvestmentFeeds(
      [
        { id: "ok", sourceName: "OK Feed", url: "https://ok-feed.example/rss" },
        { id: "bad", sourceName: "Bad Feed", url: "https://bad.example/rss" },
      ],
      mockFetch,
      "2026-05-01T00:00:00Z",
    );

    assertEquals(report.feed_statuses[0].status, "fetched");
    assertEquals(report.feed_statuses[0].item_count, 1);
    assertEquals(report.feed_statuses[1].status, "unavailable");
    assertEquals(report.records.length, 1);
    assertEquals(report.records[0].verification_status, "needs_verification");
    const md = renderCollectionMarkdown(report);
    assertEquals(md.includes("要検証"), true);
    assertEquals(
      sanitizeHttpUrl("https://example.com/a"),
      "https://example.com/a",
    );
    assertEquals(sanitizeHttpUrl("data:text/html,hi"), "");
    assertEquals(inferQuarterFromIso("2026-04-01T00:00:00Z"), "2026-Q2");
  },
);
