-- Udio コンテンツシード
-- AI大学: Udio プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: 音楽生成AI (Sunoの競合) / プロ品質インストゥルメンタル / 音楽理論に忠実 / Extend機能で長尺楽曲に対応

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('udio', 'overview', 'Udio 概要',
$$Udio は2024年に登場した**音楽生成AI**。Sunoと並ぶ音楽生成AIの双璧として知られ、特に「音楽理論に忠実な生成」と「プロ品質のインストゥルメンタル」で評価されています。元Google DeepMindのメンバーが創業し、音楽的な精緻さを重視した設計が特徴です。

## 特徴

- **音楽品質**: Sunoより音楽理論に忠実・コード進行・リズムの精度が高い
- **インストゥルメンタル**: ボーカルなしの伴奏生成が特に高品質
- **Extend機能**: 生成した楽曲を前後に自然に延長 → 最大10分以上の長尺楽曲
- **Crop・Edit**: 生成楽曲の特定セクションを編集・差し替え
- **Custom Mode**: 拍子・キー・テンポ・楽器を詳細指定

## Suno との比較

| 項目 | Udio | Suno |
| :--- | :--- | :--- |
| **音楽的精度** | ★★★★★ コード進行正確 | ★★★★ やや自由 |
| **インストゥルメンタル** | ★★★★★ 非常に高品質 | ★★★★ 高品質 |
| **ボーカル品質** | ★★★★ 良い | ★★★★★ 自然なボーカル |
| **日本語歌詞** | ★★★ 対応 | ★★★★ 対応・安定 |
| **Extend機能** | ★★★★★ 前後延長可 | ★★★ 限定的 |
| **API** | ベータ提供 | ベータ提供 |
| **月間無料枠** | 10曲/月 | 約10曲/月 |

## 主要ユースケース

| ユースケース | Udio の強み |
| :--- | :--- |
| **BGM・環境音楽** | 正確なコード進行でBGM品質が高い |
| **ジャズ・クラシック** | 音楽理論忠実な生成が得意 |
| **ゲーム・映像BGM** | Extend で長尺BGMを自然に生成 |
| **プロ制作補助** | 楽曲スケッチ・デモトラック生成 |$$,
'https://www.udio.com/', '2026-04-12', 1),

('udio', 'models', 'Udio — モデルと機能 (2026)',
$$## モデルバージョン

| バージョン | 特徴 | 楽曲長 |
| :--- | :--- | :--- |
| **Udio 130** (最新) | 最高品質・130bpmまでのテンポ対応 | 最大32秒/生成 |
| **Udio 32** | 高速生成・短いフレーズ用 | 最大32秒/生成 |

※ Extend 機能で複数セグメントを繋いで長尺楽曲を作成

## ジャンル別プロンプトガイド

```text
ジャズトリオ:
"jazz trio, upright bass, brushed drums, piano comping, bebop style,
 fast tempo, minor key, sophisticated chord changes"

映画BGM (壮大):
"cinematic orchestral, epic strings, french horns, building tension,
 no vocals, Hans Zimmer inspired, 4/4 time, dramatic crescendo"

ローファイヒップホップ:
"lo-fi hip hop, vinyl crackle, mellow boom bap, dusty samples,
 relaxed 85 BPM, headphone music, study beats"

J-POP バラード (インスト):
"japanese pop ballad instrumental, piano melody, strings arrangement,
 emotional, 75 BPM, key of A minor"

プログレッシブロック:
"progressive rock, complex time signature 7/8, guitar riffs,
 hammond organ, technical drumming, epic instrumental"
```

## Extend 機能の使い方

```text
Step 1: 最初の32秒を生成
  "Smooth jazz intro, piano solo, gentle atmosphere"

Step 2: Extend → 後ろに32秒追加
  "Continue with bass entry, walking bass pattern"

Step 3: Extend → さらに追加
  "Full band joins, drums and guitar, peak energy"

Step 4: Extend → アウトロ
  "Fade out, back to piano solo, quiet ending"

結果: 2分以上の完全な楽曲構成
```

## カスタムパラメータ

| パラメータ | 説明 | 例 |
| :--- | :--- | :--- |
| **Lyrics** | 歌詞テキスト (空ならインスト) | `[Verse]\n君の...` |
| **BPM** | テンポ指定 | `120` |
| **Key** | キー指定 | `C major` / `A minor` |
| **Time Signature** | 拍子 | `4/4` / `3/4` / `7/8` |$$,
'https://www.udio.com/about', '2026-04-12', 2),

('udio', 'api', 'Udio API 入門',
$$## API アクセス

Udio の API は**ベータ版**として提供されています。
`https://www.udio.com/account` からAPIキーを取得できます。

## Python で楽曲生成

```python
import requests
import time

UDIO_API_KEY = "<UDIO_API_KEY>"
BASE_URL = "https://www.udio.com/api"

headers = {
    "Authorization": f"Bearer {UDIO_API_KEY}",
    "Content-Type": "application/json",
}

def generate_track(prompt: str, lyrics: str = "") -> dict:
    """Udio で楽曲を生成する"""
    payload = {
        "prompt": prompt,
        "lyrics": lyrics,              # 空文字列でインストゥルメンタル
        "custom_lyrics": bool(lyrics), # カスタム歌詞フラグ
    }

    # 生成リクエスト
    response = requests.post(f"{BASE_URL}/generate-proxy", json=payload, headers=headers)
    result = response.json()

    track_ids = [track["id"] for track in result.get("tracks", [])]
    print(f"生成開始: {track_ids}")
    return result

def wait_for_completion(track_id: str, max_wait: int = 300) -> dict:
    """楽曲生成の完了を待機"""
    for i in range(max_wait // 5):
        response = requests.get(
            f"{BASE_URL}/get-track-status",
            params={"id": track_id},
            headers=headers,
        )
        track = response.json()

        if track.get("finished"):
            print(f"完成: {track.get('song_path')}")
            return track

        print(f"生成中... ({i * 5}秒経過)")
        time.sleep(5)

    raise TimeoutError("楽曲生成がタイムアウトしました")

# ジャズBGM生成
result = generate_track(
    prompt="smooth jazz trio, piano, bass, drums, late night atmosphere, 90 BPM, minor key",
    lyrics="",  # インストゥルメンタル
)

if result.get("tracks"):
    track_id = result["tracks"][0]["id"]
    completed = wait_for_completion(track_id)
    print(f"楽曲URL: {completed.get('song_path')}")
```

## カスタム歌詞で楽曲生成

```python
import requests

UDIO_API_KEY = "<UDIO_API_KEY>"

# 日本語カスタム歌詞での楽曲生成
lyrics = """[Verse]
桜舞い散る 春の夜に
君の笑顔を 思い出す
遠ざかる日々 でも忘れない
心の中で 今も輝く

[Chorus]
消えない記憶 消せない想い
この胸の中に 永遠に
季節が変わり 時が流れても
あの日の君は ここにいる"""

payload = {
    "prompt": "emotional japanese pop ballad, female vocalist, piano and strings, 70 BPM, A minor",
    "lyrics": lyrics,
    "custom_lyrics": True,
}

response = requests.post(
    "https://www.udio.com/api/generate-proxy",
    json=payload,
    headers={"Authorization": f"Bearer {UDIO_API_KEY}", "Content-Type": "application/json"},
)
print(response.json())
```

## Suno vs Udio 使い分けガイド

```python
def choose_music_ai(use_case: str) -> str:
    """ユースケースに応じて Suno か Udio を選択"""
    udio_cases = ["bgm", "instrumental", "jazz", "classical", "progressive", "film", "extend"]
    suno_cases = ["vocal", "jpop", "kpop", "rap", "catchy", "japanese_lyrics"]

    use_lower = use_case.lower()

    if any(kw in use_lower for kw in udio_cases):
        return "Udio (音楽精度・インストゥルメンタル・Extend機能が優秀)"
    elif any(kw in use_lower for kw in suno_cases):
        return "Suno (ボーカル品質・日本語歌詞・キャッチーな楽曲が得意)"
    else:
        return "両方試して好みの方を採用 (どちらも高品質)"

print(choose_music_ai("jazz instrumental bgm"))  # → Udio
print(choose_music_ai("jpop vocal song"))         # → Suno
print(choose_music_ai("electronic dance music"))  # → 両方試す
```

## 料金 (2026年4月時点)

| プラン | 月額 | クレジット | 特徴 |
| :--- | :--- | :--- | :--- |
| **Free** | $0 | 10曲/月 | 個人利用・商用不可 |
| **Standard** | $9 | 100曲/月 | 商用利用可 |
| **Pro** | $29 | 500曲/月 | 優先生成・高品質 |
| **Enterprise** | カスタム | 無制限 | API専用プラン |$$,
'https://www.udio.com/', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Udio 追加 (34社目)',
  'UdioをAI大学プロバイダーとして追加。音楽生成AI・Sunoとの比較表・Extend機能で長尺BGM生成・音楽理論に忠実なインストゥルメンタル・Suno vs Udio使い分けガイド収録。AI大学プロバイダー数 33社→34社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
