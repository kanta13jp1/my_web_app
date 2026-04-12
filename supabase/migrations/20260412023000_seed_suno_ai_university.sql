-- Suno AI コンテンツシード
-- AI大学: Suno プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: 音楽生成AI最大手 / テキスト→楽曲 / ボーカル+伴奏の完全楽曲生成 / 月間100万人以上利用

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('suno', 'overview', 'Suno AI 概要',
$$Suno AI は2022年創業の**音楽生成AI企業**。テキストで曲調・ジャンル・歌詞を指定するだけで、ボーカル・伴奏・ミックスが完成した楽曲を数十秒で生成します。音楽の知識がなくても本格的な楽曲を作れると話題になり、月間100万人以上が利用しています。

## 特徴

- **完全楽曲生成**: ボーカル・伴奏・ミックス・マスタリングまで一括生成
- **歌詞自動生成**: テーマを指定するだけでAIが歌詞も作成
- **多様なジャンル**: ポップ・ロック・EDM・ジャズ・ヒップホップ・演歌・ボサノバなど
- **日本語対応**: 日本語歌詞の楽曲生成も可能
- **v4モデル**: 2024年最新版。音質・表現力が大幅向上

## 生成フロー

```text
プロンプト:
  "A melancholic Japanese jazz song about autumn rain.
   Female vocalist. Slow tempo. Piano and bass."

    ↓ Suno v4 (約30秒)

完成楽曲:
  - ボーカルトラック (女性ジャズボーカル)
  - ピアノ・ベース・ドラム伴奏
  - プロ品質のミックス
  - MP3/WAVでダウンロード可
```

## 主要ユースケース

| ユースケース | 内容 |
| :--- | :--- |
| **コンテンツBGM** | YouTube・ポッドキャスト・動画の著作権フリーBGM |
| **プロトタイプ** | CM・映像のデモ用楽曲を低コスト・高速で制作 |
| **ゲーム・アプリ** | ゲームBGM・UI効果音・アプリのサウンドデザイン |
| **個人創作** | 趣味の作曲・歌詞の実験・音楽学習 |
| **マーケティング** | ブランドソング・ジングル・CM楽曲 |

## 競合比較 (音楽生成AI)

| サービス | 特徴 | 強み |
| :--- | :--- | :--- |
| **Suno AI** | ボーカル+楽器の完全楽曲 | 自然なボーカル・日本語対応 |
| Udio | 高品質インストゥルメンタル | 音楽的精度・プロ品質 |
| MusicGen (Meta) | OSSモデル | ローカル実行・カスタマイズ |
| ElevenLabs Music | 効果音・環境音 | 既存LLM連携 |$$,
'https://suno.com/', '2026-04-12', 1),

('suno', 'models', 'Suno AI — モデルバージョンと機能 (2026)',
$$## モデル世代比較

| バージョン | 音質 | ボーカル精度 | 楽曲長 | 特徴 |
| :--- | :--- | :--- | :--- | :--- |
| **v4** (最新) | 最高 | 非常に高い | 最大4分 | 感情表現・ダイナミクス改善 |
| **v3.5** | 高 | 高い | 最大4分 | バランス型・安定 |
| **v3** | 中高 | 良い | 最大2分 | API利用可 |

## 生成パラメータ

| パラメータ | 説明 | 例 |
| :--- | :--- | :--- |
| **Style Prompt** | 曲調・ジャンル・楽器・テンポ | `"upbeat pop, female vocal, guitar"` |
| **Lyrics** | 日本語/英語の歌詞 | カスタム歌詞 or AI自動生成 |
| **Instrumental** | 歌詞なしインストゥルメンタル | `instrumental: true` |
| **Title** | 曲名 | `"秋雨のブルース"` |
| **Duration** | 秒数指定 (v4) | 30〜240秒 |

## ジャンル別プロンプト例

```text
J-POP バラード:
"emotional japanese pop ballad, female vocalist, piano melody,
 strings arrangement, 80 BPM, melancholic mood"

ロック:
"hard rock, male vocalist, electric guitar riffs,
 heavy drums, energetic, stadium anthem style"

演歌:
"japanese enka, female singer, shamisen and piano,
 slow tempo, traditional japanese pentatonic scale, emotional"

EDM:
"energetic EDM, no vocals, heavy bass drop,
 synth leads, 128 BPM, club music, festival vibes"

ジャズ:
"smooth jazz, female singer, piano trio,
 walking bass, brushed drums, late night bar atmosphere"
```

## 生成楽曲の権利

| プラン | 商用利用 | 楽曲の帰属 |
| :--- | :--- | :--- |
| **Free** | ❌ (非商用のみ) | Suno AI 帰属必要 |
| **Pro** | ✅ | 自分に帰属 |
| **Premier** | ✅ | 自分に帰属 |$$,
'https://suno.com/about', '2026-04-12', 2),

('suno', 'api', 'Suno AI API 入門',
$$## API アクセス

Suno AI は **公式API (ベータ版)** を提供しています。
Suno Pro / Premier プランのユーザーは `app.suno.ai/account` でAPIキーを取得できます。

## Python で楽曲生成

```python
import requests
import time

SUNO_API_KEY = "<SUNO_API_KEY>"
BASE_URL = "https://studio-api.suno.ai"

headers = {
    "Authorization": f"Bearer {SUNO_API_KEY}",
    "Content-Type": "application/json",
}

# Step 1: 楽曲生成をリクエスト
payload = {
    "prompt": "A cheerful Japanese pop song about spring flowers. Female vocalist. Upbeat tempo.",
    "make_instrumental": False,  # ボーカルあり
    "model": "chirp-v3-5",       # v3.5 モデル
    "wait_audio": False,          # 非同期生成
}

response = requests.post(f"{BASE_URL}/api/generate/v2/", json=payload, headers=headers)
songs = response.json()

song_ids = [song["id"] for song in songs]
print(f"生成開始: {song_ids}")

# Step 2: 完了を待機 (ポーリング)
while True:
    feed_response = requests.get(
        f"{BASE_URL}/api/feed/",
        params={"ids": ",".join(song_ids)},
        headers=headers,
    )
    feed = feed_response.json()

    all_done = all(song.get("status") == "complete" for song in feed)
    if all_done:
        for song in feed:
            print(f"タイトル: {song['title']}")
            print(f"MP3 URL: {song['audio_url']}")
            print(f"画像 URL: {song['image_url']}")
        break

    print("生成中...")
    time.sleep(5)
```

## カスタム歌詞で楽曲生成

```python
import requests

SUNO_API_KEY = "<SUNO_API_KEY>"

# カスタム歌詞と曲調を指定
payload = {
    "prompt": "emotional japanese ballad, piano, strings, female vocalist",
    "tags": "japanese pop ballad",
    "title": "秋の記憶",
    "make_instrumental": False,
    "model": "chirp-v3-5",
    "lyric": """[Verse]
枯れ葉舞い散る 公園のベンチ
あなたと過ごした 懐かしい日々
風が運ぶ あの日の記憶
遠く消えゆく 秋の光

[Chorus]
忘れられない 忘れたくない
心に刻んだ あなたの笑顔
季節が変わっても 変わらない想い
この胸の中で 生き続ける""",
}

response = requests.post(
    "https://studio-api.suno.ai/api/custom_generate/",
    json=payload,
    headers={"Authorization": f"Bearer {SUNO_API_KEY}", "Content-Type": "application/json"},
)
print(response.json())
```

## Supabase Edge Function から呼び出し (Deno)

```typescript
// Suno AI で BGM 生成 → Supabase Storage に保存
const SUNO_API_KEY = Deno.env.get("SUNO_API_KEY")!;
const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

async function generateBGM(theme: string): Promise<string> {
  // 楽曲生成リクエスト
  const genRes = await fetch("https://studio-api.suno.ai/api/generate/v2/", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SUNO_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      prompt: `instrumental background music for ${theme}, calm, professional`,
      make_instrumental: true,
      model: "chirp-v3-5",
    }),
  });

  const songs = await genRes.json();
  const songId = songs[0].id;

  // ポーリングで完了を待機 (最大5分)
  for (let i = 0; i < 60; i++) {
    await new Promise((r) => setTimeout(r, 5000));

    const feedRes = await fetch(
      `https://studio-api.suno.ai/api/feed/?ids=${songId}`,
      { headers: { "Authorization": `Bearer ${SUNO_API_KEY}` } }
    );
    const feed = await feedRes.json();

    if (feed[0]?.status === "complete") {
      const audioUrl = feed[0].audio_url;

      // Supabase Storage に保存
      const audioRes = await fetch(audioUrl);
      const audioBuffer = await audioRes.arrayBuffer();

      await supabase.storage
        .from("bgm")
        .upload(`${songId}.mp3`, audioBuffer, { contentType: "audio/mpeg" });

      const { data } = supabase.storage.from("bgm").getPublicUrl(`${songId}.mp3`);
      return data.publicUrl;
    }
  }
  throw new Error("BGM generation timeout");
}
```

## 料金 (2026年4月時点)

| プラン | 月額 | 生成クレジット | 商用利用 |
| :--- | :--- | :--- | :--- |
| **Free** | $0 | 50クレジット/月 (約10曲) | ❌ |
| **Pro** | $10 | 2,500クレジット/月 (約500曲) | ✅ |
| **Premier** | $30 | 10,000クレジット/月 (約2,000曲) | ✅ |

- 1曲 (2バリエーション) = 5クレジット
- 延長生成 (続きの生成) = 5クレジット$$,
'https://suno.com/blog/sunoapi', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Suno AI 追加 (32社目)',
  'Suno AIをAI大学プロバイダーとして追加。音楽生成AI最大手・テキスト→完全楽曲(ボーカル+伴奏)・日本語歌詞対応・カスタム歌詞生成・Supabase Storage BGM保存例を収録。AI大学プロバイダー数 31社→32社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
