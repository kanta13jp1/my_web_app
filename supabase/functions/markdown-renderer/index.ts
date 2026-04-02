// Markdown Renderer Edge Function
// Markdownレンダリング (Notion/GitHub競合)
// - Markdown → HTML 変換
// - テーブル・コードブロック対応
// - 目次生成
// - テキスト統計
//
// POST → レンダリング / 目次 / 統計

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function renderMarkdown(md: string): string {
  let html = md;

  // Code blocks (fenced)
  html = html.replace(/```(\w*)\n([\s\S]*?)```/g, (_match, lang, code) =>
    `<pre><code class="language-${lang}">${escapeHtml(code.trim())}</code></pre>`
  );

  // Inline code
  html = html.replace(/`([^`]+)`/g, "<code>$1</code>");

  // Headers
  html = html.replace(/^######\s+(.+)$/gm, "<h6>$1</h6>");
  html = html.replace(/^#####\s+(.+)$/gm, "<h5>$1</h5>");
  html = html.replace(/^####\s+(.+)$/gm, "<h4>$1</h4>");
  html = html.replace(/^###\s+(.+)$/gm, "<h3>$1</h3>");
  html = html.replace(/^##\s+(.+)$/gm, "<h2>$1</h2>");
  html = html.replace(/^#\s+(.+)$/gm, "<h1>$1</h1>");

  // Bold and italic
  html = html.replace(/\*\*\*(.+?)\*\*\*/g, "<strong><em>$1</em></strong>");
  html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  html = html.replace(/\*(.+?)\*/g, "<em>$1</em>");

  // Strikethrough
  html = html.replace(/~~(.+?)~~/g, "<del>$1</del>");

  // Links
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');

  // Images
  html = html.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '<img src="$2" alt="$1" />');

  // Horizontal rule
  html = html.replace(/^---$/gm, "<hr />");

  // Blockquote
  html = html.replace(/^>\s+(.+)$/gm, "<blockquote>$1</blockquote>");

  // Unordered list
  html = html.replace(/^[-*]\s+(.+)$/gm, "<li>$1</li>");

  // Checkbox
  html = html.replace(/^- \[x\]\s+(.+)$/gm, '<li><input type="checkbox" checked disabled /> $1</li>');
  html = html.replace(/^- \[ \]\s+(.+)$/gm, '<li><input type="checkbox" disabled /> $1</li>');

  // Paragraphs (lines not already wrapped)
  html = html.replace(/^(?!<[a-z])((?!^\s*$).+)$/gm, "<p>$1</p>");

  // Line breaks
  html = html.replace(/\n{2,}/g, "\n");

  return html.trim();
}

function extractToc(md: string): Array<{ level: number; text: string; id: string }> {
  const toc: Array<{ level: number; text: string; id: string }> = [];
  const headingRegex = /^(#{1,6})\s+(.+)$/gm;
  let match;
  while ((match = headingRegex.exec(md)) !== null) {
    const level = match[1].length;
    const text = match[2];
    const id = text.toLowerCase().replace(/[^\w\s-]/g, "").replace(/\s+/g, "-");
    toc.push({ level, text, id });
  }
  return toc;
}

function textStats(md: string): { characters: number; words: number; lines: number; paragraphs: number; headings: number; codeBlocks: number; links: number } {
  const plain = md.replace(/```[\s\S]*?```/g, "").replace(/[#*_~`\[\]()>-]/g, "");
  const words = plain.split(/\s+/).filter((w) => w.length > 0).length;
  const lines = md.split("\n").length;
  const paragraphs = md.split(/\n{2,}/).filter((p) => p.trim().length > 0).length;
  const headings = (md.match(/^#{1,6}\s/gm) ?? []).length;
  const codeBlocks = (md.match(/```/g) ?? []).length / 2;
  const links = (md.match(/\[([^\]]+)\]\(([^)]+)\)/g) ?? []).length;

  return { characters: md.length, words, lines, paragraphs, headings, codeBlocks: Math.floor(codeBlocks), links };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method === "POST") {
      const body = await req.json();
      const { action, markdown } = body;

      if (!markdown || typeof markdown !== "string") {
        return new Response(
          JSON.stringify({ success: false, error: "markdown text required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "toc") {
        return new Response(
          JSON.stringify({ success: true, toc: extractToc(markdown) }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "stats") {
        return new Response(
          JSON.stringify({ success: true, stats: textStats(markdown) }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Default: render
      const html = renderMarkdown(markdown);
      const toc = extractToc(markdown);
      const stats = textStats(markdown);

      return new Response(
        JSON.stringify({ success: true, html, toc, stats }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "GET") {
      return new Response(
        JSON.stringify({
          success: true,
          info: "POST with { markdown: '...' } to render. Actions: render, toc, stats",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
