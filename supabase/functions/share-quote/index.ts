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

    // Supabase Functions のベースURL
    const functionsBaseUrl = url.origin;

    // OGP画像URLを生成
    const ogImageUrl = `${functionsBaseUrl}/functions/v1/generate-quote-image?id=${quoteId}`;

    // アプリのURL
    const appUrl = 'https://my-web-app-b67f4.web.app';

    // HTMLを生成（OGPメタタグを含む）
    const html = `<!DOCTYPE html>
<html lang="ja">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <!-- OGP Meta Tags -->
    <meta property="og:type" content="website">
    <meta property="og:site_name" content="マイメモ">
    <meta property="og:title" content="💭 今日の名言 - ${quote.author}">
    <meta property="og:description" content="${quote.quote}">
    <meta property="og:image" content="${ogImageUrl}">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:url" content="${url.href}">
    <meta property="og:locale" content="ja_JP">

    <!-- Twitter Card Meta Tags -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="💭 今日の名言 - ${quote.author}">
    <meta name="twitter:description" content="${quote.quote}">
    <meta name="twitter:image" content="${ogImageUrl}">
    <meta name="twitter:image:alt" content="${quote.author}の名言">

    <title>💭 ${quote.author}の名言 | マイメモ</title>

    <style>
      * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
      }

      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 20px;
        color: white;
      }

      .container {
        max-width: 800px;
        width: 100%;
        background: rgba(255, 255, 255, 0.1);
        backdrop-filter: blur(10px);
        border-radius: 24px;
        padding: 60px 40px;
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        text-align: center;
      }

      .quote-icon {
        font-size: 48px;
        margin-bottom: 20px;
        opacity: 0.9;
      }

      .quote-text {
        font-size: 28px;
        line-height: 1.6;
        margin-bottom: 30px;
        font-weight: 500;
        text-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
      }

      .quote-author {
        font-size: 20px;
        margin-bottom: 10px;
        opacity: 0.9;
        font-weight: 600;
      }

      .author-description {
        font-size: 14px;
        opacity: 0.7;
        margin-bottom: 40px;
      }

      .cta-button {
        display: inline-block;
        background: white;
        color: #667eea;
        padding: 16px 40px;
        border-radius: 50px;
        text-decoration: none;
        font-weight: bold;
        font-size: 18px;
        box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        transition: transform 0.3s ease, box-shadow 0.3s ease;
      }

      .cta-button:hover {
        transform: translateY(-2px);
        box-shadow: 0 15px 40px rgba(0, 0, 0, 0.3);
      }

      .app-name {
        margin-top: 40px;
        font-size: 24px;
        font-weight: bold;
        opacity: 0.95;
      }

      .app-tagline {
        margin-top: 10px;
        font-size: 16px;
        opacity: 0.8;
      }

      @media (max-width: 768px) {
        .container {
          padding: 40px 24px;
        }

        .quote-text {
          font-size: 22px;
        }

        .quote-author {
          font-size: 18px;
        }

        .cta-button {
          font-size: 16px;
          padding: 14px 32px;
        }
      }
    </style>
  </head>
  <body>
    <div class="container">
      <div class="quote-icon">💭</div>

      <div class="quote-text">
        「${quote.quote}」
      </div>

      <div class="quote-author">
        - ${quote.author} -
      </div>

      ${quote.authorDescription ? `
        <div class="author-description">
          ${quote.authorDescription}
        </div>
      ` : ''}

      <a href="${appUrl}" class="cta-button">
        🎮 マイメモで学びの習慣を始める
      </a>

      <div class="app-name">
        マイメモ
      </div>

      <div class="app-tagline">
        哲学者の知恵とともに、メモ習慣を楽しく継続
      </div>
    </div>
  </body>
</html>`;

    return new Response(html, {
      headers: {
        ...corsHeaders,
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'public, max-age=3600', // 1時間キャッシュ
      },
    });
  } catch (error) {
    console.error('Error in share-quote function:', error);

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
