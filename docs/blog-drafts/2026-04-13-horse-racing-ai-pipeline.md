---
title: "Flutter × Supabase で競馬AI予想パイプラインを全自動化した話 — JRA+NAR両対応・前走情報まで実装"
tags: Flutter,Supabase,個人開発,buildinpublic,機械学習
published: true
---

# Flutter × Supabase で競馬AI予想パイプラインを全自動化した話 — JRA+NAR両対応・前走情報まで実装

## はじめに

「AIで競馬予想ができたら面白い」という発想から始まり、Flutter UI・Supabase Edge Function・GitHub Actions をつなぎ合わせた**完全自動化パイプライン**を構築しました。

JRA (中央競馬) だけでなく **NAR (地方競馬) 15場**にも対応し、さらに**前走情報・馬体重・年齢性別**の詳細データも表示できるようになりました。

---

## アーキテクチャ全体像

```
[JRA/NAR データ取得]  → fetch_horse_racing.py (Python)
        ↓
[tools-hub EF]        → horseracing.today / predict_all / predictions / accuracy
        ↓
[Supabase DB]         → horse_races / horse_results テーブル
        ↓
[horse-racing-update.yml] → 1時間毎に自動実行 (GitHub Actions)
        ↓
[Flutter UI]          → horse_racing_predictor_page.dart (3タブ構成)
```

---

## データ取得: JRA + NAR 完全対応

Python スクリプト `fetch_horse_racing.py` が JRA と NAR 両方のデータを EUC-JP エンコーディングで取得します。

```python
# JRA: netkeiba.com から EUC-JP でデータ取得
# NAR: 地方競馬 15場 (大井・川崎・船橋など) に対応

response = requests.get(url, headers=headers, timeout=10)
# EUC-JP の文字化けを回避: errors='replace' で確定デコード
content = response.content.decode('euc-jp', errors='replace')
```

**詰まりポイント**: Windows 環境の Python は CP932 エンコードがデフォルト。EUC-JP のバイト列をそのまま読もうとすると文字化けします。`errors='replace'` で unknown バイトを置換することで安定化しました。

---

## Edge Function: tools-hub のアクション分岐

EF ハードキャップ (50本以下) を守るため、競馬機能は全て `tools-hub` の `action` 分岐で実装:

```typescript
// tools-hub/index.ts
switch (action) {
  case 'horseracing.today':
    return await getHorseRacingToday(supabase);
  case 'horseracing.predict_all':
    return await predictAllRaces(supabase, body);
  case 'horseracing.predictions':
    return await getPredictions(supabase, body);
  case 'horseracing.accuracy':
    return await getAccuracyStats(supabase);
}
```

### 認証ゾーンの設計

GitHub Actions から JWT なしで呼び出せるよう、`horseracing.*` アクションは全て認証不要の「Stateless ゾーン」に配置しています。

`tools-hub/index.ts` では `horseracing.` で始まるアクションを認証チェック (`getUserId`) より前のブロックで処理します:

```typescript
// ── Horse Racing 自動化パイプライン (auth不要 — GitHub Actions対応) ─────────
if (action.startsWith("horseracing.")) {
  switch (action) {
    case "horseracing.today":     return await getHorseRacingToday(admin);
    case "horseracing.predict_all": return await predictAllRaces(admin, body);
    case "horseracing.predictions": return await getPredictions(admin, body);
    case "horseracing.accuracy":  return await getAccuracyStats(admin);
    // ... 計8アクション (list_races / store_results / register_race / stats)
  }
}

// ↓ ここから先が認証必須ゾーン
const userId = await getUserId(req);
if (!userId) return json({ error: "Unauthorized" }, 401);
```

当初 auth 必須ゾーンに混在していたため GitHub Actions から 401 エラーが発生。`horseracing.*` ブロックごと stateless セクションへ移動して解消しました。

### horse_results の 500 エラー解消

全レース結果を一括 SELECT するとタイムアウト。**Promise.all で並列個別クエリ**に変更:

```typescript
// After: 個別クエリ並行実行
const results = await Promise.all(
  raceIds.map(id =>
    supabase.from('horse_results').select('*').eq('race_id', id)
  )
);
```

---

## GitHub Actions: 1時間毎の完全自動実行

```yaml
# .github/workflows/horse-racing-update.yml
on:
  schedule:
    - cron: "0 * * * *"  # 毎時00分

jobs:
  update:
    steps:
      - name: Run all modes
        run: |
          python fetch_horse_racing.py --mode today
          python fetch_horse_racing.py --mode predict
          python fetch_horse_racing.py --mode accuracy
```

`--mode all` を追加したことで、1 回のジョブ実行でデータ取得・AI予想・的中率更新の全工程を完了させられるようになりました。

---

## Flutter UI: 3タブ + 前走情報

`horse_racing_predictor_page.dart` は3タブ構成:

| タブ | 内容 |
|------|------|
| 今日のレース | ExpansionTile でレースカード展開、グレードバッジ (G1=赤/G2=青/G3=緑) |
| 予想履歴 | 過去のAI予想一覧、日付フィルタ |
| 的中率 | ヒット率%・総予想数・最高払戻し |

### グレードカラーバッジ

```dart
Color _gradeColor(String grade) => switch (grade) {
  'G1' => Colors.red.shade700,
  'G2' => Colors.blue.shade700,
  'G3' => Colors.green.shade700,
  _    => Colors.grey.shade600,
};
```

### 前走情報 (最新追加)

直近セッション (Windows版#68 → VSCode版#70) で**前走情報・馬体重・年齢性別**を追加:

```dart
// 前走情報カード
ListTile(
  title: Text('前走: ${horse.prevRaceName}'),
  subtitle: Text(
    '前走着順: ${horse.prevRaceRank}位 | '
    '馬体重: ${horse.weight}kg | '
    '${horse.age}歳 ${horse.sex}'
  ),
)
```

マイグレーション:
```sql
ALTER TABLE horse_races
  ADD COLUMN prev_race_name  text,
  ADD COLUMN prev_race_rank  int,
  ADD COLUMN horse_weight    int,
  ADD COLUMN horse_age       int,
  ADD COLUMN horse_sex       text;
```

---

## まとめ

| 機能 | 実装状況 |
|------|---------|
| JRA データ取得 | ✅ netkeiba.com EUC-JP対応 |
| NAR 地方競馬 15場 | ✅ 大井/川崎/船橋 etc. |
| AI予想生成 | ✅ tools-hub EF |
| 1時間毎自動更新 | ✅ GitHub Actions cron |
| 前走情報・馬体重 | ✅ VSCode版#70 で追加 |
| 的中率ダッシュボード | ✅ Flutter 3タブUI |

競馬予想の精度向上は今後の課題ですが、**データ取得→AI予想→UI表示まで完全自動化**という基盤は完成しました。

---

自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #個人開発 #buildinpublic #競馬AI
