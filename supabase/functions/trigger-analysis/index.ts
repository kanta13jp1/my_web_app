// supabase/functions/trigger-analysis/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const GITHUB_TOKEN = Deno.env.get('GITHUB_PAT')
// あなたのリポジトリ情報に書き換えてください
const REPO_OWNER = 'kanta13jp1' 
const REPO_NAME = 'my_web_app'
const WORKFLOW_FILE = 'cron-batch.yml' // 定期実行用ファイルのファイル名

serve(async (req) => {
  // CORSヘッダー（ブラウザ/アプリからのアクセス許可）
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    }})
  }

  try {
    // 1. GitHub API を叩いて Action をトリガー
    const response = await fetch(
      `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/workflows/${WORKFLOW_FILE}/dispatches`,
      {
        method: 'POST',
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'Authorization': `Bearer ${GITHUB_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ref: 'main', // 実行するブランチ
        }),
      }
    )

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`GitHub API Error: ${response.status} ${errorText}`)
    }

    return new Response(
      JSON.stringify({ message: 'Batch analysis triggered successfully' }),
      { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )
  }
})