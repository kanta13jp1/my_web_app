import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  analyzePdfWithWriter,
  detectPdfPageCount,
  estimatedWriterParserCostUsd,
  handlePdfDocumentAnalysisAction,
  isOwnerScopedPdfPath,
  PDF_ANALYSIS_BUCKET,
  type PdfAnalysisStorage,
} from "./pdf_document_analysis.ts";

function pdf(pageCount = 3): Uint8Array {
  const pages = Array.from(
    { length: pageCount },
    (_, index) => `${index + 1} 0 obj << /Type /Page /Parent 99 0 R >> endobj`,
  ).join("\n");
  return new TextEncoder().encode(
    `%PDF-1.7\n99 0 obj << /Type /Pages /Count ${pageCount} >> endobj\n${pages}\n%%EOF`,
  );
}

Deno.test("detectPdfPageCount counts multi-page PDFs", () => {
  assertEquals(detectPdfPageCount(pdf(12)), 12);
  assertEquals(detectPdfPageCount(new TextEncoder().encode("not-pdf")), 0);
  assertEquals(estimatedWriterParserCostUsd(12), 0.66);
});

Deno.test("isOwnerScopedPdfPath rejects traversal and other owners", () => {
  assertEquals(isOwnerScopedPdfPath("user-1/input/report.pdf", "user-1"), true);
  assertEquals(
    isOwnerScopedPdfPath("user-2/input/report.pdf", "user-1"),
    false,
  );
  assertEquals(isOwnerScopedPdfPath("user-1/../report.pdf", "user-1"), false);
});

Deno.test("handler requires renewed confirmation when server page count differs", async () => {
  const storage = new FakeStorage(pdf(4));
  let writerCalled = false;
  const result = await handlePdfDocumentAnalysisAction({
    storage,
    userId: "user-1",
    body: {
      storage_path: "user-1/input/report.pdf",
      confirmed_page_count: 3,
      file_name: "report.pdf",
    },
    enabled: true,
    writerApiKey: "test-key",
    allowExternalProvider: true,
    writerAnalyzer: () => {
      writerCalled = true;
      throw new Error("should not run");
    },
  });

  assertEquals(result.status, 409);
  assertEquals(result.body.code, "page_count_changed");
  assertEquals(result.body.page_count, 4);
  assertEquals(writerCalled, false);
  assertEquals(storage.removed, ["user-1/input/report.pdf"]);
});

Deno.test("handler returns structured multi-page analysis and deletes input", async () => {
  const storage = new FakeStorage(pdf(5));
  const spends: number[] = [];
  const result = await handlePdfDocumentAnalysisAction({
    storage,
    userId: "user-1",
    body: {
      storage_path: "user-1/input/report.pdf",
      confirmed_page_count: 5,
      file_name: "Quarterly report.pdf",
      format: "markdown",
    },
    enabled: true,
    writerApiKey: "test-key",
    allowExternalProvider: true,
    authorizeSpend: (cost) => Promise.resolve(cost === 0.275),
    recordSpend: (cost) => {
      spends.push(cost);
      return Promise.resolve();
    },
    writerAnalyzer: (request) => {
      assertEquals(request.bytes.length > 0, true);
      assertEquals(request.format, "markdown");
      return Promise.resolve({
        extractedContent: "# Quarterly report\nRevenue increased.",
        title: "Quarterly report",
        summary: "Revenue increased.",
        keyPoints: ["Revenue +10%"],
        importantFields: [{ label: "Revenue", value: "$10M" }],
        model: "palmyra-x5",
        extractionTruncated: false,
      });
    },
  });

  assertEquals(result.status, 200);
  assertEquals(result.body.success, true);
  assertEquals((result.body.document as Record<string, unknown>).page_count, 5);
  assertEquals(spends, [0.275]);
  assertEquals(storage.bucket, PDF_ANALYSIS_BUCKET);
  assertEquals(storage.removed, ["user-1/input/report.pdf"]);
});

Deno.test("handler fail-closes while feature flag is disabled and cleans up", async () => {
  const storage = new FakeStorage(pdf(2));
  const result = await handlePdfDocumentAnalysisAction({
    storage,
    userId: "user-1",
    body: {
      storage_path: "user-1/input/report.pdf",
      confirmed_page_count: 2,
    },
    enabled: false,
    writerApiKey: "test-key",
    allowExternalProvider: true,
  });
  assertEquals(result.status, 503);
  assertEquals(result.body.code, "feature_unavailable");
  assertEquals(storage.downloads, 0);
  assertEquals(storage.removed, ["user-1/input/report.pdf"]);
});

Deno.test("Writer flow uploads, parses, summarizes, then deletes the file", async () => {
  const calls: Array<{ url: string; method: string }> = [];
  const responses = [
    new Response(JSON.stringify({ id: "writer-file-1" }), { status: 200 }),
    new Response(JSON.stringify({ content: "# Report\nPage one\nPage two" }), {
      status: 200,
    }),
    new Response(
      JSON.stringify({
        model: "palmyra-x5",
        choices: [{
          message: {
            content: JSON.stringify({
              title: "Report",
              summary: "Two pages summarized.",
              key_points: ["Point A"],
              important_fields: [{ label: "Owner", value: "Example" }],
            }),
          },
        }],
      }),
      { status: 200 },
    ),
    new Response("{}", { status: 200 }),
  ];
  const fetcher = ((input: string | URL | Request, init?: RequestInit) => {
    calls.push({
      url: String(input),
      method: String(init?.method ?? "GET"),
    });
    return Promise.resolve(responses.shift()!);
  }) as typeof fetch;

  const result = await analyzePdfWithWriter({
    apiKey: "test-key",
    bytes: pdf(2),
    fileName: "report.pdf",
    format: "markdown",
  }, fetcher);

  assertEquals(result.summary, "Two pages summarized.");
  assertEquals(calls, [
    { url: "https://api.writer.com/v1/files", method: "POST" },
    {
      url: "https://api.writer.com/v1/tools/pdf-parser/writer-file-1",
      method: "POST",
    },
    { url: "https://api.writer.com/v1/chat", method: "POST" },
    {
      url: "https://api.writer.com/v1/files/writer-file-1",
      method: "DELETE",
    },
  ]);
});

class FakeStorage implements PdfAnalysisStorage {
  bucket?: string;
  downloads = 0;
  readonly removed: string[] = [];

  constructor(readonly bytes: Uint8Array) {}

  from(bucket: string) {
    this.bucket = bucket;
    return {
      download: (_path: string) => {
        this.downloads++;
        return Promise.resolve({ data: this.bytes, error: null });
      },
      remove: (paths: string[]) => {
        this.removed.push(...paths);
        return Promise.resolve({ error: null });
      },
    };
  }
}
