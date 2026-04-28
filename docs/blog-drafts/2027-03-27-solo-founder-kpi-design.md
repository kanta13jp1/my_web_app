---
title: "ソロ創業者のKPI設計 — 「昨日の自分」との比較が唯一の正しい指標"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# ソロ創業者のKPI設計 — 「昨日の自分」との比較が唯一の正しい指標

「MAU が競合より少ない」「MRR が目標に届いていない」。こういう指標で自分を評価し続けると消耗します。ソロ創業者に適したKPI設計を、このプロジェクトの実装例とともに公開します。

## 競合比較KPIの問題

```
競合 Notion: MAU 3,000万人
自分: MAU 50人

→ 「全然ダメだ」という結論しか出ない
→ しかし、この比較に意味はあるか？
```

Notion には1,000人のエンジニアと10億ドルの資金がある。ソロ創業者が同じ指標で競合と比べるのは、小学生がオリンピック選手とタイムを比べるようなもの。

## 「昨日の自分」比較フレーム

```
正しい比較:
  先週: MAU 40人
  今週: MAU 50人
  → 25%成長 ✅

ではなく:
  競合: MAU 3,000万人
  自分: MAU 50人
  → 0.0002% ❌
```

自分株式会社のプロジェクト哲学 (PHILOSOPHY.md) にある「KPI = 昨日の自分」の原則。成長率・改善率・学習速度を測る。

## 実装: development_achievements テーブル

```sql
CREATE TABLE development_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL,  -- 'feature' | 'content' | 'infra' | 'learning'
  completed_at DATE NOT NULL,
  session_id TEXT,
  instance_name TEXT
);
```

毎セッション末に achievement を記録:

```sql
-- セッション後の定型 seed
INSERT INTO development_achievements (title, description, category, completed_at, instance_name)
VALUES (
  'T-1 Phase8 完結 dev.to 62本達成',
  'Flutter PWA / AI大学設計思想 / worktree / GHA の4テーマを投稿',
  'content',
  '2026-04-28',
  'ps2'
) ON CONFLICT DO NOTHING;
```

## KPI ダッシュボードの設計

```dart
// Edge Function から取得するメトリクス
class SoloFounderKpi {
  final int devAchievementsThisWeek;    // 今週の開発実績数
  final int devAchievementsLastWeek;    // 先週の開発実績数
  final int blogPostsTotal;             // 累計ブログ投稿数
  final int blogPostsThisMonth;         // 今月投稿数
  final double aiCostMoM;               // AI コスト月次変化率
  final int activeUsersToday;           // 今日のアクティブユーザー数
  final int activiUsersLastWeek;        // 先週同日比
}

// 表示ロジック
String get weeklyAchievementTrend {
  final delta = devAchievementsThisWeek - devAchievementsLastWeek;
  if (delta > 0) return '+$delta (↑ 成長)';
  if (delta == 0) return '同値 (→ 維持)';
  return '$delta (↓ 要注意)';
}
```

## 測定すべき指標の分類

**成長指標 (週次で追う)**:
- 開発 achievement 数 (今週 vs 先週)
- ブログ投稿数 (累計)
- AI大学 provider 数 (累計)
- 競合ページ数 (累計)

**健全性指標 (月次で追う)**:
- Claude Code コスト (先月比)
- GHA 利用分数 (無料枠との比率)
- deploy 成功率

**ユーザー指標 (毎日確認)**:
- DAU (昨日比)
- サポートチケット未対応数
- エラーレート

## 絶対値ではなく変化率を見る

```
悪い見方: 「MAU が 50人しかいない」
良い見方: 「先週から 25% 増えた」

悪い見方: 「ブログが 62本しかない」
良い見方: 「1ヶ月前は 28本だった。2倍以上に増えた」

悪い見方: 「AI コストが $230/月かかる」
良い見方: 「$230 で12人分の作業ができている。ROI 20x以上」
```

## 停滞の早期発見

変化率が連続3週間ゼロ以下になったときだけアラートを出す:

```typescript
// schedule-hub の weekly check
function detectStagnation(weeklyAchievements: number[]): boolean {
  if (weeklyAchievements.length < 3) return false;
  const last3 = weeklyAchievements.slice(-3);
  return last3.every((v, i) => i === 0 || v <= last3[i-1]);
}
```

「停滞している」という事実を早期発見して原因分析に移行する。競合と比べて落ち込む時間は0にする。

## まとめ

ソロ創業者に適したKPI設計:
1. **比較対象は過去の自分だけ** — 競合比較は戦略立案時のみ
2. **変化率を測る** — 絶対値は文脈なしに意味をなさない
3. **achievement を記録する** — 主観的な「頑張った」を客観化
4. **停滞を検出する仕組みを作る** — 感情ではなくデータで判断
5. **ROI で測る** — 「$230 で12人分」という計算が正しい自己評価

競合に勝つ必要はない。昨日の自分に勝ち続ければ、3ヶ月後には別の人間になっている。
