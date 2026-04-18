---
date: 2026-04-18
from: Windowsアプリ版#90
to: VSCode版
status: pending
priority: high
---

# ホーム画面 5階層カスタマイズ機能

## 概要

ユーザーがホーム画面のレイアウトを自分好みにカスタマイズできるようにする。  
表示順・カスタマイズ機能を 5 階層に整理し、可変部分はユーザー設定で制御可能にする。

Windows版#90 で既に `CollapsibleHomeSection` widget (アコーディオン) を作成済み。
本 PR はその上に **5 階層レイアウトシステム** を構築する依頼。

## 5 階層構成 (上から順)

| # | セクション | 内容 | データソース |
| --- | --- | --- | --- |
| 1 | **最近使った機能** | 直近 N 件のタップ履歴 (LRU) | `user_feature_usage` テーブル (新規) |
| 2 | **システム固定機能** | 運営が全ユーザーに必須で出したい機能 | `home_fixed_system.dart` 定数配列 |
| 3 | **ユーザー固定機能** | ユーザーがピン留めした機能 | `user_pinned_features` テーブル (新規) |
| 4 | **最近追加された機能** | 新規ページ/機能 (ここ 14 日) | `feature_releases` テーブル (新規) |
| 5 | **AI おすすめ機能** | AI 判断による個人レコメンド | `ai-hub:home.recommend` action (新規) |

## 依頼内容

### 1. 新規テーブル migration (3本)

```sql
-- user_feature_usage: タップ履歴
CREATE TABLE user_feature_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  feature_route text NOT NULL,
  feature_label text,
  tapped_at timestamptz DEFAULT now()
);
CREATE INDEX ON user_feature_usage(user_id, tapped_at DESC);

-- user_pinned_features: ユーザーピン留め
CREATE TABLE user_pinned_features (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  feature_route text NOT NULL,
  feature_label text,
  sort_order integer DEFAULT 0,
  UNIQUE(user_id, feature_route)
);

-- feature_releases: 最近追加された機能
CREATE TABLE feature_releases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_route text NOT NULL,
  feature_label text NOT NULL,
  description text,
  released_at timestamptz DEFAULT now(),
  category text
);
CREATE INDEX ON feature_releases(released_at DESC);
```

### 2. home_page.dart を 5 階層レイアウトへリファクタ

以下のように `CollapsibleHomeSection` を 5 個並べる構造:

```dart
ListView(
  children: [
    CollapsibleHomeSection(
      storageKey: 'home_tier_recent',
      title: '最近使った機能',
      icon: Icons.history,
      child: RecentFeaturesList(),  // 新規
    ),
    CollapsibleHomeSection(
      storageKey: 'home_tier_system',
      title: 'システム固定機能',
      icon: Icons.lock_outline,
      child: SystemFixedFeaturesList(),  // 新規
    ),
    CollapsibleHomeSection(
      storageKey: 'home_tier_pinned',
      title: 'お気に入り (ピン留め)',
      icon: Icons.push_pin_outlined,
      child: UserPinnedFeaturesList(),  // 新規
    ),
    CollapsibleHomeSection(
      storageKey: 'home_tier_new',
      title: '最近追加された機能',
      icon: Icons.new_releases_outlined,
      child: NewFeaturesList(),  // 新規
    ),
    CollapsibleHomeSection(
      storageKey: 'home_tier_recommend',
      title: 'AI おすすめ機能',
      icon: Icons.auto_awesome,
      child: AiRecommendedFeaturesList(),  // 新規
    ),
  ],
)
```

### 3. 5 tier サブウィジェット (5本)

各セクションの中身を担う widget を `lib/widgets/home_tier/` 配下に作成:

- `recent_features_list.dart`: `SELECT feature_route FROM user_feature_usage WHERE user_id=X ORDER BY tapped_at DESC LIMIT 8`
- `system_fixed_features_list.dart`: `lib/data/home_system_fixed.dart` に定義されたリストから生成
- `user_pinned_features_list.dart`: `SELECT FROM user_pinned_features WHERE user_id=X ORDER BY sort_order`. **ピン追加・ドラッグ並び替え** 可能
- `new_features_list.dart`: `SELECT FROM feature_releases WHERE released_at > NOW() - INTERVAL '14 days'`
- `ai_recommended_features_list.dart`: `ai-hub:home.recommend` 呼び出し → top 5 レコメンド

### 4. 機能使用ログ追加

既存の全機能タップ導線に:
```dart
await Supabase.instance.client.from('user_feature_usage').insert({
  'user_id': userId,
  'feature_route': '/my-ai-agent',
  'feature_label': 'AI秘書',
});
```

ラッパー関数化 (`recordFeatureTap(context, route, label)`) して各 Navigator.push の前に呼ぶ。

### 5. ピン留めトグル UI

各機能カード右上に Icons.push_pin / push_pin_outlined トグル。タップで `user_pinned_features` に insert/delete。

### 6. ai-hub:home.recommend (PS版依頼は別途)

本 PR は Flutter UI のみ。PS 版への別 PR で `ai-hub:home.recommend` action を追加 (入力: user profile + 使用履歴 / 出力: top 5 feature_route)。

## 関連ファイル

- `lib/pages/home_page.dart` (ListView 中央部分をリファクタ)
- `lib/widgets/collapsible_home_section.dart` (Windows#90 で作成済)
- `lib/widgets/home_tier/*.dart` (5本新規)
- `lib/data/home_system_fixed.dart` (新規)
- `supabase/migrations/202604180XXXXX_*.sql` (3本)

## 完了条件

- [ ] migration 3 本 (user_feature_usage / user_pinned_features / feature_releases)
- [ ] 5 tier サブウィジェット実装
- [ ] home_page.dart に CollapsibleHomeSection × 5 配置
- [ ] 機能タップ履歴記録ヘルパー実装
- [ ] ピン留めトグル UI
- [ ] flutter analyze 0エラー / dart format pass
- [ ] PS版 cross-instance-pr (ai-hub:home.recommend) 依頼作成

完了後 `done/20260418_home_5tier_customization.md` へ移動。

## 参考

- 既存: `lib/widgets/collapsible_home_section.dart` (アコーディオンラッパー)
- Kepion 参考: `docs/architecture/kepion-reference-2026-04-18.md`
