import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { quotes, getQuoteById } from "../_shared/quotes.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // CORSプリフライトリクエストへの対応
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const quoteIdParam = url.searchParams.get('id');

    // クエリパラメータがない場合はランダム
    let quoteId: number;
    if (quoteIdParam) {
      quoteId = parseInt(quoteIdParam);
      if (isNaN(quoteId)) {
        quoteId = Math.floor(Math.random() * quotes.length);
      }
    } else {
      quoteId = Math.floor(Math.random() * quotes.length);
    }

    const quote = getQuoteById(quoteId);

    // テキストを折り返す関数
    const wrapText = (text: string, maxLength: number): string[] => {
      const lines: string[] = [];
      let currentLine = '';

      for (const char of text) {
        if (currentLine.length >= maxLength) {
          lines.push(currentLine);
          currentLine = char;
        } else {
          currentLine += char;
        }
      }

      if (currentLine) {
        lines.push(currentLine);
      }

      return lines;
    };

    // 名言を折り返し（30文字ごと）
    const quoteLines = wrapText(quote.quote, 30);
    const quoteY = 280;
    const lineHeight = 60;

    // SVGテキストエレメントを生成
    const quoteSvgElements = quoteLines.map((line, index) => {
      const y = quoteY + (index * lineHeight);
      return `<text x="600" y="${y}" font-size="48" font-weight="bold" fill="white" text-anchor="middle" style="text-shadow: 0 4px 12px rgba(0,0,0,0.3);">${escapeXml(line)}</text>`;
    }).join('\n');

    const authorY = quoteY + (quoteLines.length * lineHeight) + 60;

    // SVG画像を生成（1200x630 OGP標準サイズ）
    const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg width="1200" height="630" xmlns="http://www.w3.org/2000/svg">
  <!-- グラデーション背景 -->
  <defs>
    <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />
    </linearGradient>

    <!-- パターン（装飾用） -->
    <pattern id="dots" x="0" y="0" width="60" height="60" patternUnits="userSpaceOnUse">
      <circle cx="15" cy="15" r="2" fill="rgba(255,255,255,0.1)" />
    </pattern>
  </defs>

  <!-- 背景 -->
  <rect width="1200" height="630" fill="url(#bgGradient)" />
  <rect width="1200" height="630" fill="url(#dots)" />

  <!-- 装飾的なシェイプ -->
  <circle cx="100" cy="100" r="80" fill="rgba(255,255,255,0.05)" />
  <circle cx="1100" cy="530" r="100" fill="rgba(255,255,255,0.05)" />

  <!-- クォートマーク -->
  <text x="100" y="180" font-size="120" fill="rgba(255,255,255,0.2)" font-weight="bold">"</text>
  <text x="1100" y="560" font-size="120" fill="rgba(255,255,255,0.2)" font-weight="bold" text-anchor="end">"</text>

  <!-- 名言テキスト -->
  ${quoteSvgElements}

  <!-- 著者名 -->
  <text x="600" y="${authorY}" font-size="36" fill="rgba(255,255,255,0.95)" text-anchor="middle" font-weight="600">
    - ${escapeXml(quote.author)} -
  </text>

  ${quote.authorDescription ? `
  <text x="600" y="${authorY + 40}" font-size="20" fill="rgba(255,255,255,0.75)" text-anchor="middle">
    ${escapeXml(quote.authorDescription)}
  </text>
  ` : ''}

  <!-- ロゴとキャッチコピー -->
  <g transform="translate(600, 570)">
    <text x="0" y="0" font-size="28" font-weight="bold" fill="white" text-anchor="middle">
      マイメモ
    </text>
    <text x="0" y="30" font-size="16" fill="rgba(255,255,255,0.85)" text-anchor="middle">
      哲学者と学ぶメモ習慣
    </text>
  </g>
</svg>`;

    // SVGを返す
    return new Response(svg, {
      headers: {
        ...corsHeaders,
        'Content-Type': 'image/svg+xml; charset=utf-8',
        'Cache-Control': 'public, max-age=31536000', // 1年間キャッシュ
      },
    });
  } catch (error) {
    console.error('Error in generate-quote-image function:', error);

    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});

// XMLエスケープ関数
function escapeXml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}
