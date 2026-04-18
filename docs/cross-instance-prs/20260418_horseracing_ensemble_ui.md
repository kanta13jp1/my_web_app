---
date: 2026-04-18
from: Windowsアプリ版#94
to: VSCode版
status: pending
priority: high
---

# 競馬 AI 予想ページ マルチプロバイダーアンサンブル UI

## 概要

ユーザー要望「quota 制限に達したら他のAIプロバイダーのAPIに切り替えられないか。複数のAIプロバイダーのモデルを組み合わせて予想を蓄積して、どんどん予想の精度をあげていくような機能にしたい」。

Windowsアプリ版#94 で EF 基盤を実装済み (migration + tools-hub 新 action):

- `horse_race_predictions_ensemble` テーブル: 1レース × 複数プロバイダー予想を蓄積
- `horse_prediction_accuracy` テーブル: プロバイダー別的中率を追跡
- `horse_provider_leaderboard` ビュー: プロバイダー別リーダーボード
- tools-hub 新 action: `predict_ensemble` / `consensus` / `provider_leaderboard` / `evaluate_accuracy`
- `predict_all` を Gemini → OpenAI → Claude → xAI の fallback chain に拡張 (quota 時に自動切替)

VSCode版で対応する Flutter UI を実装してください。

## 依頼内容

### 1. 予想詳細表示: プロバイダー別予想タイル + コンセンサス

`lib/pages/horse_racing_predictor_page.dart` または 新 `lib/pages/horseracing_race_detail_page.dart`:

1. レースタップ時に `tools-hub:horseracing.consensus { race_id }` を呼び出し
2. 各プロバイダーの予想を 1 tile として表示:
   ```
   ┌─ Gemini 2.5 Flash ──────────── 信頼度 72% ─┐
   │ ◎1番 ○3番 ▲5番                               │
   │ 根拠: 前走上がり3F最速、馬場傾向合致              │
   └──────────────────────────────────────────┘
   ```
3. 最上部に **コンセンサス panel**: 多数決 1 着予想 + 得票数 + 信頼度加重スコア
   - 例: `コンセンサス: 1番 (4社中3社一致・加重 2.15) 信頼度 75%`
4. 「ensemble 再実行」ボタン: `tools-hub:horseracing.predict_ensemble { race_id, force: true }` を叩いて未予想プロバイダー分を補完

### 2. プロバイダー別リーダーボード

新 `lib/pages/horse_provider_leaderboard_page.dart`:

- `tools-hub:horseracing.provider_leaderboard` を叩く
- テーブル表示: 順位 / プロバイダー:モデル / 1 着的中率 / 3連単的中率 / 予想回数
- デザイン: `docs/DESIGN.md` Orange+Indigo ダークテーマ (競馬ページのカラー)
- home_page.dart から導線追加 (CollapsibleHomeSection 内に「AI競馬的中率」タイル)

### 3. 予想表示リスト: プロバイダー badge

`lib/pages/horse_racing_predictor_page.dart` の既存予想一覧カード:

- `ai_model` フィールドが `google:gemini-2.5-flash` 形式に変わったため、`provider:model` parse して表示
- Badge 色: google=blue / openai=green / anthropic=orange / xai=grey
- 同時に「アンサンブル数: N 社」badge も表示 (既予想 provider 数)

### 4. (任意) ensemble 進捗インジケータ

`horse_racing_predictor_page.dart` で予想一括実行時:

- `predict_all` レスポンスの `provider_stats` を解析してプロバイダー別試行/成功/quota 数を可視化
- 「Gemini quota 到達 → OpenAI に fallback 実行中」通知

## 関連ファイル

- `supabase/functions/tools-hub/index.ts` (新 action 実装済み)
- `supabase/migrations/20260418170000_horse_race_ensemble_predictions.sql`
- `lib/pages/horse_racing_predictor_page.dart` (既存予想ページ)
- `docs/DESIGN.md` (デザイントークン参照)

## 完了条件

- [ ] レース詳細で consensus action を呼び出してプロバイダー別予想表示
- [ ] コンセンサスパネル (多数決1着 + 得票 + 加重スコア)
- [ ] 「ensemble 再実行」ボタン (predict_ensemble force=true)
- [ ] プロバイダー別リーダーボードページ新規作成
- [ ] home_page.dart にリーダーボード導線追加
- [ ] 予想一覧カードに provider badge 表示
- [ ] `flutter analyze` 0 エラー / `docs/DESIGN.md` トークン準拠
- [ ] 本番 (`my-web-app-b67f4.web.app`) で実機検証

完了後に `done/20260418_horseracing_ensemble_ui.md` へ移動してください。

## 補足: EF 呼び出しサンプル

```dart
// コンセンサス取得
final res = await Supabase.instance.client.functions.invoke(
  'tools-hub',
  body: {'action': 'horseracing.consensus', 'race_id': raceId},
);
final consensus = res.data['consensus'];
// consensus = {first_pick, votes, weighted_score, providers, agreement_rate}

// アンサンブル予想実行 (全プロバイダー並列)
await Supabase.instance.client.functions.invoke(
  'tools-hub',
  body: {
    'action': 'horseracing.predict_ensemble',
    'race_id': raceId,
    'force': false,  // true=再予想
    // 'providers': ['google','openai'], // 任意: 限定可
  },
);

// リーダーボード
final lb = await Supabase.instance.client.functions.invoke(
  'tools-hub',
  body: {'action': 'horseracing.provider_leaderboard'},
);
// lb.data['leaderboard'] = [{provider, model, total_predictions, first_hit_rate, ...}]
```
