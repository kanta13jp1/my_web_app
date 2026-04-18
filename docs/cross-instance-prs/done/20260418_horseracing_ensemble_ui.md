---
date: 2026-04-18
from: Windowsアプリ版#94
to: VSCode版
status: pending
priority: high
---

# 競馬 AI 予想ページ マルチプロバイダーアンサンブル UI (netkeiba 風レイアウト)

## 概要

ユーザー要望:
1. 「quota 制限に達したら他のAIプロバイダーのAPIに切り替えられないか。複数のAIプロバイダーのモデルを組み合わせて予想を蓄積して、どんどん予想の精度をあげていくような機能にしたい」
2. **「netkeiba のような UI にしたい」** (2026-04-18 追加要望) — 出走表形式で、各 AI プロバイダー = 1 カラムとして印 (◎○▲△☆) を並べる

参考画像: <https://race.netkeiba.com/yoso/mark_list.html?race_id=202603010305&rf=race_submenu>
(出走表 × 複数予想者のマトリックス表示 / 枠色ハイライト / 馬体重・単勝・人気表示)

Windowsアプリ版#94 で EF 基盤を実装済み (migration + tools-hub 新 action):

- `horse_race_predictions_ensemble` テーブル: 1レース × 複数プロバイダー予想を蓄積
- `horse_prediction_accuracy` テーブル: プロバイダー別的中率を追跡
- `horse_provider_leaderboard` ビュー: プロバイダー別リーダーボード
- tools-hub 新 action: `predict_ensemble` / `consensus` / `provider_leaderboard` / `evaluate_accuracy`
- `predict_all` を Gemini → OpenAI → Claude → xAI の fallback chain に拡張 (quota 時に自動切替)

VSCode版で対応する Flutter UI を実装してください。

## netkeiba 風レイアウト仕様 (最重要・ユーザー要望)

### 出走表マトリックス (メインビュー)

各行 = 1 頭、各列 = (枠/馬番/各AI予想印/馬名/性齢/斤量/騎手/厩舎/馬体重/単勝/人気)

```
┌─┬──┬────┬────┬────┬────┬─────────┬────┬────┬────┬────┬────────┬──────┬────┐
│枠│馬番│Gemini│GPT │Claude│Grok │コンセンサス│馬名 │性齢│斤量│騎手 │厩舎    │馬体重 │単勝│
├─┼──┼────┼────┼────┼────┼─────────┼────┼────┼────┼────┼────────┼──────┼────┤
│1│ 1 │ ◎  │ ○ │ ◎  │ ▲ │  ◎ 3票  │モンロ│牡3 │55.0│舟山 │栗東 牧浦│458(-8)│8.1 │
│1│ 2 │ △  │ ▲ │ △  │ △ │  △ 3票  │テクノ│牝3 │55.0│小沢 │栗東 楢口│446(-2)│34.8│
│2│ 3 │ ○  │ ◎ │ ○  │ ○ │  ○ 3票  │ミリオ│牡3 │55.0│長浜 │美浦 蛯名│460(-6)│5.5 │
│2│ 4 │ ─ │ △ │ ─  │ △ │    ─   │ウイン│牡3 │54.0│遠藤 │美浦 嘉藤│436(-2)│15.9│
│3│ 5 │ ─ │ ─ │ ─  │ ─ │    ─   │ファビ│牝3 │52.0│田山 │栗東 前川│430(+4)│27.8│
│3│ 6 │ △  │ ─ │ ▲  │ ─ │    ▲   │ホウオ│牡3 │55.0│鷲頭 │美浦 奥村│444(-6)│68.4│
└─┴──┴────┴────┴────┴────┴─────────┴────┴────┴────┴────┴────────┴──────┴────┘
```

### 予想印のマッピング

各プロバイダーの `first_pick / second_pick / third_pick` (horse_name) を `horse_entries` の馬名と突き合わせて以下の印を決める:

| 予想順位 | 印 | 色 |
| --- | --- | --- |
| 1 着予想 | ◎ | `Color(0xFFDC2626)` (赤) |
| 2 着予想 | ○ | `Color(0xFF2563EB)` (青) |
| 3 着予想 | ▲ | `Color(0xFFF59E0B)` (橙) |
| (将来) 4〜5 着候補 | △ | `Color(0xFF6B7280)` (灰) |
| 予想外 | ─ or 空欄 | — |

### 枠番の色 (classic keiba frame colors)

```dart
Color frameColor(int waku) {
  switch (waku) {
    case 1: return const Color(0xFFFFFFFF); // 白 (border黒)
    case 2: return const Color(0xFF1E1E1E); // 黒
    case 3: return const Color(0xFFDC2626); // 赤
    case 4: return const Color(0xFF2563EB); // 青
    case 5: return const Color(0xFFFACC15); // 黄
    case 6: return const Color(0xFF16A34A); // 緑
    case 7: return const Color(0xFFF97316); // 橙
    case 8: return const Color(0xFFEC4899); // 桃
    default: return const Color(0xFF9CA3AF);
  }
}

Color frameTextColor(int waku) => (waku == 1 || waku == 5) ? Colors.black : Colors.white;
```

### レースヘッダー (netkeiba 風)

```
╔══════════════════════════════════════════════╗
║ 5R  3歳未勝利                                      ║
║ 12:05 発走 / 芝 1800m (右 A) / 天候:晴 / 馬場:良          ║
║ 1回 福島 3日目 サラ系3歳 未勝利 / 見習騎手 / 馬齢 16頭       ║
║ 本賞金: 590,240,150,89,59 万円                        ║
╚══════════════════════════════════════════════╝
```

`horse_races` テーブルの既存カラム (`race_name`, `venue`, `course_type`, `distance`, `race_date`, `grade`, `race_number`, `post_time`等) から組み立てる。

### コース/レース番号タブ

画面上部に `1R 2R 3R ... 12R` の横スクロールタブ + 前日/翌日の日付タブ (4/11 / 4/12 / 4/18 / 4/19 等)。同一日の複数場 (中山/阪神/福島) も切替ボタンで。

### 実装ファイル構成

```
lib/pages/horseracing/
  horseracing_race_detail_page.dart      # netkeiba 風マトリックスメイン
  horseracing_provider_leaderboard_page.dart  # リーダーボード
  widgets/
    race_matrix_table.dart               # DataTable or CustomPaint で出走表
    frame_number_badge.dart              # 枠色バッジ
    prediction_mark.dart                 # ◎○▲△ 描画
    consensus_cell.dart                  # 票数入りコンセンサスセル
    race_header_card.dart                # レースヘッダー
    race_number_tab_bar.dart             # 1R〜12R タブ
```

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

- [ ] **netkeiba 風マトリックステーブル**: 出走表 × 各 AI 予想印 ◎○▲△
- [ ] **枠番の色付け**: classic keiba 8 色 (白/黒/赤/青/黄/緑/橙/桃)
- [ ] **レースヘッダー**: 発走時刻・距離・馬場・天候・グレード (netkeiba 風)
- [ ] **1R〜12R タブ**: 同日同場のレース番号切替
- [ ] **日付タブ + 開催場切替**: 前日/当日/翌日 + 中山/阪神/福島 等
- [ ] コンセンサス列: 多数決 1 着印 + 得票 (例: `◎ 3票`)
- [ ] 「ensemble 再実行」ボタン (predict_ensemble force=true)
- [ ] プロバイダー別リーダーボードページ新規作成
- [ ] home_page.dart にリーダーボード導線追加 (CollapsibleHomeSection)
- [ ] 予想一覧カードに provider badge 表示 (google=blue/openai=green/anthropic=orange/xai=grey)
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
