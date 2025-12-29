// OGP Randomizer Proxy
// Returns one of the 3 Five Emperors images randomly.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  // 1. ランダムに1〜3の番号を決定
  const variant = Math.floor(Math.random() * 3) + 1;
  
  // 2. 実際の画像のURLを構築 (自分のアプリのURLに書き換えてください)
  // デプロイ後は自動的にこのパスになります
  const baseUrl = "https://my-web-app-b67f4.web.app"; 
  const imageUrl = `${baseUrl}/ogp_v${variant}.png`;

  try {
    // 3. 画像を取得 (Fetch)
    const imageResponse = await fetch(imageUrl);
    
    // 4. 画像データとしてそのままブラウザ/Botに返す (プロキシ動作)
    // これにより、Botは「リダイレクト」ではなく「画像そのもの」として認識します
    return new Response(imageResponse.body, {
      headers: {
        "Content-Type": "image/png",
        "Cache-Control": "no-cache, no-store, must-revalidate", // キャッシュ抑制を試みるヘッダー
      },
    });
  } catch (error) {
    return new Response("Image not found", { status: 404 });
  }
})
