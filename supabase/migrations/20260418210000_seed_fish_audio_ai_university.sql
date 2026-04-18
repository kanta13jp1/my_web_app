-- Fish Audio 初期コンテンツシード (2026-04-18)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('fish_audio', 'overview', 'Fish Audio 概要',
$$**Fish Audio** は中国発の **音声 AI 専業プラットフォーム**。エンタープライズ品質のテキスト音声合成 (TTS) と、わずか数秒のサンプルから即時ボイスクローニングを実現する。

1,000+ プリビルド音声と 70+ 言語をサポート。リアルタイムストリーミング TTS により、生成中の音声を逐次再生でき、会話 AI / 音声アシスタント / インタラクティブストーリーテリングに最適。

オープンソースモデル「**Fish Speech S1**」も公開しており、自社ホスティングも可能。

## 主要サービス
- TTS API: 70+ 言語 / 1,000+ 音声
- Voice Cloning: 5〜30 秒サンプルから即時クローン
- Real-time Streaming: WebSocket でフレーム単位返却
- Fish Speech S1 (OSS): GitHub 公開・自社ホスト可

## 強み
- **超低遅延** — 最初の音声フレームを 200ms 以内で返却
- **多言語強い** — 中国語・日本語・英語の品質が特に高い
- **OSS モデル併用** — クローズド API + オープン重みのハイブリッド$$,
'https://fish.audio/', '2026-04-18', 1),

('fish_audio', 'models', 'Fish Audio モデル一覧 (2026)',
$$## 主要モデル

| モデル | 種別 | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Fish Speech S1** | TTS / OSS | フラッグシップ多言語 TTS | プロダクション |
| **Fish Speech S1-Mini** | TTS / OSS | 軽量版・エッジ可 | モバイル/組込 |
| **Voice Clone v2** | TTS | 5秒サンプル即時クローン | キャラ音声 |
| **Real-time Stream** | TTS | WebSocket ストリーミング | 会話 AI |

## 特徴的な機能
- **Artificial Analysis WER**: 音声認識精度ベンチマーク掲載 (英語/中国語 SOTA 級)
- **多言語** — 70+ 言語、特に CJK が高品質
- **GitHub OSS**: https://github.com/fishaudio/fish-speech$$,
'https://fish.audio/docs', '2026-04-18', 2),

('fish_audio', 'api', 'Fish Audio API 入門',
$$## Fish Audio API の始め方

```python
import requests

# API key を環境変数 FISH_API_KEY に設定
resp = requests.post(
    "https://api.fish.audio/v1/tts",
    headers={"Authorization": "Bearer $FISH_API_KEY"},
    json={
        "text": "こんにちは、Fish Audio です。",
        "reference_id": "voice-id-here",
        "format": "mp3",
        "stream": False
    }
)
with open("output.mp3", "wb") as f:
    f.write(resp.content)
```

## 料金 (2026年4月時点)
- **Standard TTS**: $15 / 100万文字
- **Voice Cloning**: $1 / クローン作成
- **Real-time Streaming**: $20 / 100万文字
- 無料枠: $1 クレジット + 月間 1万文字

OSS Fish Speech S1 は GitHub から無料ダウンロード可$$,
'https://fish.audio/docs/api', '2026-04-18', 3)

ON CONFLICT DO NOTHING;
