-- Session PS#3-S19: AI大学 137 社化 — Kyutai 追加
-- Kyutai = フランス OSS voice AI ラボ (Moshi / Helium / Unmute)
-- €300M funding (Xavier Niel + Rodolphe Saadé + Eric Schmidt)
-- 全成果物 CC-BY 4.0 で完全 OSS 公開
-- Step 0: 9/9 満点

INSERT INTO ai_university_content (provider, category, title, content, updated_at)
VALUES
  (
    'kyutai',
    'overview',
    'Kyutai — フランス OSS voice AI ラボ (Moshi / Helium / €300M)',
    $md$
# Kyutai — フランス OSS voice AI ラボ (Moshi / Helium / €300M)

2023 年 11 月パリ創業、**完全 OSS** (CC-BY 4.0) の AI 研究所。
創業資金 **€300M** (≒$330M) を Xavier Niel (Iliad 創業者) + Rodolphe Saadé (CMA CGM CEO) + Eric Schmidt (ex Google CEO) が供出。
**非営利** / フランス政府応援 / 全成果物を論文+コード+ weights で公開する方針。

## 既存 136 社との差別化
| 観点 | Kyutai | OpenAI (Voice) | ElevenLabs | 11Labs Turbo |
|------|--------|----------------|------------|--------------|
| duplex (同時発話) | ✅ full-duplex 160ms 理論 / 200ms 実測 | ❌ turn-based | ❌ TTS only | ❌ |
| OSS | ✅ CC-BY 4.0 完全 OSS | ❌ | ❌ | ❌ |
| 自宅推論 | ✅ PyPI 1 line / MLX/Rust/Candle | ❌ API only | ❌ API only | ❌ |
| ライセンス | Apache 2.0 + CC-BY 4.0 | proprietary | proprietary | proprietary |
| 資金 | €300M 非営利 | $10B+ (profit) | $250M | — |

## 主要プロダクト
- **Moshi** (2024-07 公開): 世界初 OSS full-duplex voice AI / 7B Helium base + Mimi codec
- **Helium-1** (2025-01): 6 欧州言語対応 lightweight モデル / mobile 向け
- **Unmute** (2025): 音声模倣 / 70 感情スタイル
- **Mimi**: ストリーミング neural audio codec (Moshi 基礎)

## 自分株式会社での活用
- voice-memo EF: Moshi で duplex 会議録取得 → 即 summary + next action
- daily-judgment: 音声で即入力 (duplex なので「考えながら口にする」が可能)
- user-manual: Unmute で 70 感情付き音声 tutorial を自動生成
- 競合 (OpenAI Voice Mode / Slack Huddle AI) に対し **OSS + 自宅実行** で差別化
$md$,
    NOW()
  ),
  (
    'kyutai',
    'models',
    'Moshi / Helium / Mimi — モデル全ラインナップ',
    $md$
# Moshi / Helium / Mimi — モデル全ラインナップ

## Moshi (voice duplex)
- **7B Helium** ベース / 2.1T tokens (英語 public data) 訓練
- **full-duplex**: ユーザー話中に AI も発話可能 (turn-based ではない)
- 理論 latency **160ms** / L4 GPU 実測 **200ms**
- **Mimi audio codec**: 24kHz mono / 1.1 kbps / 80ms チャンク
- 公開 variant: Moshika (女性声) / Moshiko (男性声) / PyTorch bf16 + int8

## Helium-1 (2025-01 公開)
- Lightweight LLM / 6 欧州言語対応 (fr/de/es/it/nl/pt)
- **mobile 実行可能** (量子化済 / iPhone/Android 両対応)
- License: Apache 2.0 (weights も含む)
- 用途: オンデバイス多言語対話 / Moshi 新 base 候補

## Mimi (neural audio codec)
- streaming 対応 audio codec (非 streaming codec の 10-100x 高速)
- Encodec (Meta) / SoundStream (Google) 後継
- 1.1 kbps で 24kHz mono を loss ≈ 無視レベルで再現
- 他 AI voice 研究者が基盤として再利用可

## 料金
- **全モデル無料** (CC-BY 4.0 / Apache 2.0)
- 商用利用 OK (帰属表示必要)
- ホスティングは自前 (self-host) / AWS/Azure/GCP で PyPI 経由即動
$md$,
    NOW()
  ),
  (
    'kyutai',
    'api',
    'Moshi / Helium SDK — 自分株式会社での組込手順',
    $md$
# Moshi / Helium SDK — 自分株式会社での組込手順

## インストール (PyPI)
```bash
pip install moshi              # PyTorch バックエンド
pip install moshi-mlx          # Apple Silicon (MLX)
cargo install --git https://github.com/kyutai-labs/moshi moshi-backend  # Rust/Candle
```

## Moshi duplex 会話 (最小構成)
```python
from moshi.models import loaders
from moshi.server import start_server

# 日本語は未対応 → Helium-1 fr 版 + jp prompting で近似
mimi = loaders.get_mimi("kmhf://kyutai/moshiko-pytorch-bf16", device="cuda")
moshi = loaders.get_moshi_lm("kmhf://kyutai/moshiko-pytorch-bf16", device="cuda")

# localhost:8998 で WebSocket サーバー起動 (Flutter Web から WSS 接続可)
start_server(mimi, moshi, host="0.0.0.0", port=8998)
```

## Flutter Web 組込 (voice_memo_page.dart 拡張例)
```dart
final ws = WebSocketChannel.connect(Uri.parse('wss://moshi.example.com:8998/ws'));

// マイク入力 → Mimi encoder → WS 送信
await for (final chunk in micChunks(80)) {
  ws.sink.add(chunk);  // 80ms PCM chunk
}

// 同時に AI 音声を受信・再生 (full-duplex!)
ws.stream.listen((audioBytes) {
  audioPlayer.playBytes(audioBytes);
});
```

## ai-hub 統合提案 (Win版 cross-instance-pr 候補)
```typescript
// supabase/functions/ai-hub/index.ts に追加
case 'voice.duplex_session':
  // 自宅 GPU or RunPod で Moshi server 起動
  // Flutter 側は wss:// 直結でよいが、hub 経由なら RBAC + trace_id 付与可
  return await kyutaiMoshiSession(body);
```

## 試す
- Web: https://kyutai.org/
- GitHub: https://github.com/kyutai-labs/moshi
- HuggingFace: https://huggingface.co/kyutai
- Unmute (demo): https://unmute.sh/
- Moshi 論文: https://kyutai.org/Moshi.pdf

## フランス政府との関係
- EU AI Act の「open-source 例外条項」を Kyutai がロビイング成功
- パリ AI Summit 2025 (Macron 主催) で Kyutai が欧州代表例として紹介
- CNRS + INRIA と研究連携 (論文 5+ 本共著)
$md$,
    NOW()
  )
ON CONFLICT (provider, category) DO UPDATE
SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
