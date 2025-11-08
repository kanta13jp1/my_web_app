const { getQuoteById } = require('./quotes');

// HTML escaping function
function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

exports.handler = async (event, context) => {
  // CORS headers
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
  };

  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 204,
      headers,
      body: ''
    };
  }

  try {
    // Get quote ID from query parameter
    const params = event.queryStringParameters || {};
    const quoteIdParam = params.id;
    let quoteId = 0;

    if (quoteIdParam) {
      quoteId = parseInt(quoteIdParam);
      if (isNaN(quoteId)) {
        quoteId = Math.floor(Math.random() * 35);
      }
    } else {
      quoteId = Math.floor(Math.random() * 35);
    }

    const quote = getQuoteById(quoteId);

    // URLs
    const functionsBaseUrl = 'https://smmkxxavexumewbfaqpy.supabase.co';
    const ogImageUrl = `${functionsBaseUrl}/functions/v1/generate-quote-image?id=${quoteId}`;
    const appUrl = 'https://my-web-app-b67f4.web.app';

    // Netlify URL will be different - we'll use the event URL
    const netlifyUrl = `https://${event.headers.host}`;
    const shareUrl = `${netlifyUrl}/.netlify/functions/share-quote?id=${quoteId}`;

    // Generate HTML with OGP meta tags
    const html = `<!DOCTYPE html>
<html lang="ja">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <!-- OGP Meta Tags -->
    <meta property="og:type" content="website">
    <meta property="og:site_name" content="${escapeHtml('マイメモ')}">
    <meta property="og:title" content="${escapeHtml('💭 今日の名言 - ' + quote.author)}">
    <meta property="og:description" content="${escapeHtml(quote.quote)}">
    <meta property="og:image" content="${ogImageUrl}">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:url" content="${shareUrl}">
    <meta property="og:locale" content="ja_JP">

    <!-- Twitter Card Meta Tags -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="${escapeHtml('💭 今日の名言 - ' + quote.author)}">
    <meta name="twitter:description" content="${escapeHtml(quote.quote)}">
    <meta name="twitter:image" content="${ogImageUrl}">
    <meta name="twitter:image:alt" content="${escapeHtml(quote.author + 'の名言')}">

    <title>${escapeHtml('💭 ' + quote.author + 'の名言 | マイメモ')}</title>

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
      <div class="quote-icon">${escapeHtml('💭')}</div>

      <div class="quote-text">
        ${escapeHtml('「' + quote.quote + '」')}
      </div>

      <div class="quote-author">
        ${escapeHtml('- ' + quote.author + ' -')}
      </div>

      ${quote.authorDescription ? `
        <div class="author-description">
          ${escapeHtml(quote.authorDescription)}
        </div>
      ` : ''}

      <a href="${appUrl}" class="cta-button">
        ${escapeHtml('🎮 マイメモで学びの習慣を始める')}
      </a>

      <div class="app-name">
        ${escapeHtml('マイメモ')}
      </div>

      <div class="app-tagline">
        ${escapeHtml('哲学者の知恵とともに、メモ習慣を楽しく継続')}
      </div>
    </div>
  </body>
</html>`;

    // Return HTML response
    return {
      statusCode: 200,
      headers: {
        ...headers,
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'public, max-age=3600',
      },
      body: html
    };

  } catch (error) {
    console.error('Error in share-quote function:', error);

    return {
      statusCode: 500,
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ error: error.message })
    };
  }
};
