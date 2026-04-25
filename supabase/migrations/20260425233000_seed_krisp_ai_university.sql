-- PS#3 S52: AI大学 199→200社化 — Krisp 追加
-- Krisp: AI ノイズキャンセリング & ミーティングアシスタント / $9.5M / 20M+ ユーザー

INSERT INTO ai_university_content (provider, category, title, content, sort_order)
VALUES
(
  'krisp',
  'overview',
  'Krisp — AI ノイズキャンセリング & ミーティングアシスタント (CPU DNN / 20M+ ユーザー)',
  $md$## Krisp — AI ノイズキャンセリング & ミーティングアシスタント

**カテゴリ**: AI Audio Processing / Meeting Intelligence
**設立**: 2017年 / 本社: サンフランシスコ (アルメニア系創業)
**調達**: $9.5M (Shanda Group / Tonal など)
**ユーザー数**: 20M+ ダウンロード (2024年時点)
**評価**: ★8/9

### 概要
Krisp は AI を使ったノイズキャンセリング + ミーティングアシスタントアプリ。通話中の背景雑音・エコー・残響を双方向でリアルタイム除去し、Zoom・Teams・Google Meet・Slack など任意のビデオ会議ツールに対応する。2022 年以降は AI ミーティング文字起こし・サマリー機能を追加し、Meeting Assistant として進化。

### 主な特長
- **双方向ノイズ除去**: 自分のマイクと相手のスピーカー両方の雑音をリアルタイム除去
- **エコー・残響キャンセル**: カフェ・在宅などどんな環境でもクリアな音声を確保
- **AI ボイスクリア**: 音声品質を自動的に高める AI アップサンプリング
- **Meeting Transcription**: リアルタイム文字起こし (英語主体、多言語対応)
- **AI サマリー**: 会議終了後に要点・アクションアイテムを自動生成
- **任意アプリ対応**: 仮想マイク/スピーカーとして動作するため Zoom/Teams/Slack/Discord など全アプリに適用

### 競合との差別化
| ツール | 特徴 |
|--------|------|
| **NVIDIA RTX Voice** | GPU 使用・高精度。RTX GPU 必須 |
| **Zoom AI Companion** | Zoom 内蔵。他アプリ非対応 |
| **Microsoft Teams Noise Suppression** | Teams 専用 |
| **SoliCall** | ハードウェア処理型 |

Krisp の強みは **アプリ非依存 × CPU ベース (GPU 不要) × ミーティングアシスタント統合**。

### 導入コスト
- **Free**: ノイズキャンセリング 60 分/日・文字起こし 10 回/月
- **Pro**: $8/月 (無制限ノイズキャンセリング・文字起こし・サマリー)
- **Business**: $12/席/月 (管理コンソール・SSO・CRM 統合)
$md$,
  1
),
(
  'krisp',
  'api',
  $md$## Krisp API / SDK

### Krisp SDK (B2B 組み込み)
Krisp は音声処理エンジンを SDK として提供。通話アプリや Web RTC アプリに組み込み可能。

**対応プラットフォーム**:
- **Windows / macOS**: ネイティブ SDK (C++)
- **Web (WebAssembly)**: ブラウザ内リアルタイム処理
- **iOS / Android**: モバイル SDK (β)

**主な API**:
```javascript
// Web SDK 例
import { KrispSDK } from '@krisp/krisp-sdk';

const krisp = new KrispSDK({ apiKey: 'YOUR_API_KEY' });
await krisp.init();

// マイクトラックにノイズキャンセリング適用
const cleanStream = await krisp.applyToStream(microphoneStream);
```

### Meeting Transcription API
- REST API でミーティング音声 → テキスト変換
- ウェブフックで文字起こし完了通知
- Zapier / Make 連携で CRM / Slack に自動転送

### 制限事項
- SDK は Enterprise 契約が必要 (問い合わせ形式)
- Web SDK: Chrome / Edge 推奨。Safari は制限あり
$md$,
  2
),
(
  'krisp',
  'models',
  $md$## Krisp の AI モデル

| 用途 | 技術 |
|------|------|
| ノイズキャンセリング | 独自 DNN (Deep Neural Network) |
| エコーキャンセル | 独自 AEC モデル |
| 音声品質向上 | AI アップサンプリング |
| 文字起こし | Whisper ベース (内部拡張) |
| サマリー生成 | GPT-4 / Claude (内部) |

### 技術的特徴
- **CPU ベース**: GPU 不要で低スペック PC でも動作 (CPU 使用率 < 5%)
- **オンデバイス処理**: 音声データをクラウドに送らずローカル処理 (プライバシー保護)
- **リアルタイム低遅延**: < 20ms 処理遅延でネイティブ通話体験を維持

### 自分株式会社での活用可能性
- リモートミーティング環境改善 (雑音多い在宅 / カフェ作業時)
- AI 大学 Tech Talk / Podcast 収録のノイズ除去
- 投資家面談・クライアントコール品質向上
- SDK を使った音声機能組み込み (将来の AI コーチ機能)
$md$,
  198
)
ON CONFLICT DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 199→200社化: Krisp 追加',
  'PS#3 S52。Krisp (AI ノイズキャンセリング & ミーティングアシスタント / CPU ベース DNN / 双方向雑音除去 / 文字起こし + AI サマリー / $9.5M 調達 / 20M+ ユーザー / ★8/9) を ai_university_content に追加。AI大学 200社マイルストーン達成。',
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
