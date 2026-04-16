---
title: "Flutter × Supabase で競馬AI予想パイプラインを全自動化した話 — 3タブUI・的中率ダッシュボード実装"
tags: Flutter,Supabase,個人開発,buildinpublic,競馬AI
published: true
---

# ブログ下書き 2026-04-12

## タイトル案
1. Flutter × Supabase で競馬AI予想パイプラインを全自動化した話 — 的中率・払戻し表示まで実装
2. AIが競馬を予想する時代 — Flutter UIで3連単予想・的中率ダッシュボードを作った
3. 自分株式会社がAI大学40社を超えた日 & 競馬AI予想パイプラインを本番リリースした話

## 投稿先候補
- [ ] Zenn
- [ ] Qiita
- [ ] note
- [ ] はてなブログ
- [ ] X Article
- [ ] Medium
- [ ] dev.to
- [ ] Hashnode
- [ ] Substack
- [ ] GitHub Pages
- [ ] NOTION

## 本文下書き

### はじめに

「AIで競馬予想ができたら面白い」という発想から始まったこの機能を、今週ついに Flutter UI まで含めた **完全自動化パイプライン** として本番リリースしました。

同じ週に **AI大学のプロバイダー数が40社を突破**するという節目も重なり、自分株式会社（`https://my-web-app-b67f4.web.app/`）として大きなマイルストーンとなりました。

本記事では以下の2点について技術的に掘り下げます。

1. **競馬AI自動予想パイプライン** — Edge Function (Deno) × Flutter UI の設計
2. **AI大学40社体制** — 多プロバイダーをスケーラブルに管理する DB 駆動アーキテクチャ

---

### 実装方法

#### 1. 競馬AI予想パイプライン全体像

```
[JRA データ取得] → [tools-hub EF: horseracing.today]
        ↓
[AI予想生成]    → [tools-hub EF: horseracing.predict_all]
        ↓
[予想保存]      → [Supabase: horse_results テーブル]
        ↓
[Flutter UI]    → [horse_racing_predictor_page.dart]
```

**Edge Function 側 (Deno)**

`tools-hub` は複数のアクション (`today` / `predict_all` / `predictions` / `accuracy`) を1本のEFにまとめたハブ構成です。CLAUDE.md のルール7「EFハードキャップ50本以下」に従い、新機能追加時は既存ハブへの `action` 追加を最優先にしています。

```typescript
// tools-hub/index.ts (抜粋)
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

**Flutter UI 側**

`horse_racing_predictor_page.dart` は3タブ構成にリニューアルしました。

| タブ | 内容 |
|------|------|
| 今日のレース | ExpansionTile でレースカード展開、グレード色バッジ表示 |
| 予想履歴 | 過去のAI予想一覧、日付フィルタ |
| 的中率 | ヒット率%・総予想数・的中数・最高払戻し金額 |

払戻し金額の表示には `NumberFormat('#,###')` を使い、3桁区切りで視認性を向上。グレードによってバッジ色を変える実装も加えました（G1=赤、G2=青、G3=緑）。

```dart
Color _gradeColor(String grade) {
  return switch (grade) {
    'G1' => Colors.red.shade700,
    'G2' => Colors.blue.shade700,
    'G3' => Colors.green.shade700,
    _ => Colors.grey.shade600,
  };
}
```

#### 2. AI大学40社体制 — DB駆動タブ管理

AI大学は今週だけで **34社 → 40社** に拡大しました。追加されたプロバイダーは以下の通り：

| セッション | 追加プロバイダー |
|------------|-----------------|
| Windows版#57 | Luma AI, Kling AI |
| Windows版#58 | Pika Labs, AssemblyAI |
| Windows版#59 | Twelve Labs, Cohere |

各プロバイダーは `ai_university_content` テーブルの `provider` カラムで管理されており、Flutter 側ではテーブルから取得したプロバイダー一覧を動的にタブ生成します。新プロバイダー追加時にコード変更不要な「DB駆動アーキテクチャ」が功を奏しています。

```dart
// タブは DB から動的生成
final providers = await _fetchProviders();
return TabBar(
  tabs: providers.map((p) => Tab(text: p.displayName)).toList(),
);
```

また、今週は **Rule19 デザイン修正**も同時実施しました：

- AppBar の背景色を `surface1` に統一
- TabBar を indigo カラーに変更
- 本文 `line-height` を 1.6 → 1.7 に引き上げ（日本語読みやすさ改善）

---

### 詰まったポイント

#### tools-hub の認証ゾーン分類

`horseracing.predictions` は GitHub Actions のスケジューラから呼び出すため、JWT 認証が不要です。当初 `auth` ゾーンに配置していたため GitHub Actions からの呼び出しが 401 エラーで失敗していました。

**解決策**: アクションを `no_auth` ゾーンに移動し、サービスキー不要で呼び出せるように変更。

```typescript
const NO_AUTH_ACTIONS = ['horseracing.today', 'horseracing.predictions'];
```

#### horse_results の個別クエリで 500 エラー

最初の実装では全レース結果を一括 SELECT していましたが、データ量が多い場合にタイムアウトが発生。**個別クエリ + Promise.all** に変更して解消しました。

```typescript
// Before: 一括取得 → タイムアウト
const { data } = await supabase.from('horse_results').select('*');

// After: 個別クエリ並行実行
const results = await Promise.all(
  raceIds.map(id => supabase.from('horse_results').select('*').eq('race_id', id))
);
```

#### deploy-prod の SQLSTATE 42P10

AI大学コンテンツの UPSERT で `SQLSTATE 42P10`（対象列が一意でない）エラーが発生。`ai_university_content` テーブルの `(provider, category)` に `UNIQUE` 制約が必要でしたが、既存マイグレーションで抜けていました。

```sql
ALTER TABLE ai_university_content
  ADD CONSTRAINT ai_university_content_provider_category_key
  UNIQUE (provider, category);
```

---

### まとめ

今週の主要な実装まとめ：

- **競馬AI予想パイプライン** の Flutter UI を完全刷新（3タブ・ExpansionTile・的中率ダッシュボード）
- **AI大学が40社を突破**、DB駆動アーキテクチャで追加コストゼロを実現
- **EFハードキャップ遵守**: 新機能は tools-hub の action 追加で対応、EF 総数は 15 本以下を維持
- **Rule19 デザイン修正**: line-height・TabBar・AppBar を DESIGN.md トークンに準拠

次のステップとして、競馬予想の精度向上のため Perplexity Sonar API との連携と、AI大学の **学習リマインダー定期バッチ**（`schedule-hub: reminders.study`）の本番稼働を予定しています。

サービスはこちらから無料でお試しいただけます:
https://my-web-app-b67f4.web.app/

#FlutterWeb #Supabase #buildinpublic #競馬AI #AI大学
