---
title: "Flutter + Supabase で PMF前のプロダクトに「勝つためのダッシュボード」を実装した話"
emoji: "🚀"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["flutter", "supabase", "dart", "startup", "buildinpublic"]
published: false
---

## はじめに

こんにちは！ Notion、Evernote、MoneyForward、X といった巨大な競合を超えるべく、個人で知的生産プラットフォーム「[自分株式会社](https://example.com)」を開発しています。

現在の登録者数は恥ずかしながらまだ2人。まさにプロダクトマーケットフィット（PMF）前の暗くて長いトンネルの中にいます。

この状況で最も重要なのは、**自分たちが今どこにいて、どこに向かっているのかを正確に把握し、高速で意思決定を繰り返すこと**です。そのために、プロダクト自身のホーム画面に、開発チーム（といっても自分一人ですが）のための「Growth Dashboard」を実装しました。

この記事では、Flutter (Web) と Supabase を使って、どうやってこの「勝つためのダッシュボード」を構築したのか、その技術的な裏側と設計思想についてお話しします。

## 完成した Growth Dashboard

百聞は一見に如かず。まずは完成したホーム画面の主要コンポーネントをご覧ください。

![Growth Dashboard のスクリーンショット](https-::)
*(これはUIのイメージです)*

ホーム画面は、主に以下の3つの情報を提供します。

1.  **Growth Roadmap 進捗カード:** 巨大な競合に対する現在の進捗を、ユーザー数をベースにリアルタイムで可視化します。
2.  **競合機能比較カード:** Notion や Evernote など、各競合との機能的なギャップを一覧で確認し、次に取り組むべき開発タスクの優先順位付けに役立てます。
3.  **主要KPIとネクストアクション:** 総資産やタスクの完了状況といった主要KPIを集約し、AIが「次に何をすべきか」を提案します。

これらのダッシュボード機能を自分たち自身が毎日見ることで、日々の開発に迷いがなくなり、モチベーションを維持する強力な武器になっています。

## 技術スタック

- **フロントエンド:** Flutter (Web)
- **バックエンド/DB:** Supabase

Flutter の描画パフォーマンスと開発体験、そして Supabase の手軽さを組み合わせることで、高速なイテレーションを実現しています。特に Supabase は、DB、Auth、Edge Functions がシームレスに連携するため、スモールチーム（たとえ一人でも）の強力な味方です。

## 実装解説①: GrowthRoadmapProgressCard

![Roadmap Progress Card のスクリーンショット](https-::)

これは、プロダクトの最終目標に対する現在の立ち位置を視覚的に示す、最も重要なカードです。

### データの持ち方

目標値は `_PlanItem` というシンプルなクラスで、コード内に静的に定義しています。将来的にDB管理に移行することも可能ですが、現時点ではこれで十分です。

```dart:lib/widgets/growth_roadmap_progress_card.dart
class _PlanItem {
  final String label;
  final String? deadline;
  final int target;
  // ...
}

static const _plans = [
  _PlanItem(label: '短期計画', deadline: '2026年06月30日', target: 100),
  _PlanItem(label: 'vs NOTION', target: 100000000),
  _PlanItem(label: 'vs EverNote', target: 250000000),
  _PlanItem(label: 'vs MoneyForward', target: 15000000),
  _PlanItem(label: 'vs X', target: 600000000),
];
```

### Supabase からリアルタイムのユーザー数を取得

現在の進捗（ユーザー数）は、Supabase の `user_profiles` テーブルから `count()` を使って取得します。`postgrest-js` のおかげで、非常に直感的に書けます。

```dart:lib/widgets/growth_roadmap_progress_card.dart
Future<void> _loadUserCount() async {
  try {
    final response = await _supabase
        .from('user_profiles')
        .select('user_id')
        .count(CountOption.exact); // .count() で件数を取得
    if (!mounted) return;
    setState(() {
      _userCount = response.count;
      _isLoading = false;
    });
  } catch (_) {
    // エラーハンドリング
  }
}
```

### 進捗の表示

取得したユーザー数と目標値を元に、各プランの進捗率を計算し、`_PlanProgressRow` ウィジェットでプログレスバーと共に表示します。プログレスバーは `■` と `□` を `join()` して作る、昔ながらのテキストベースの実装も併記しているのが小さなこだわりです。

```dart:lib/widgets/growth_roadmap_progress_card.dart
class _PlanProgressRow extends StatelessWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    final ratio = (currentCount / plan.target).clamp(0.0, 1.0);
    final pct = (ratio * 100).toStringAsFixed(1);
    final filledSegments = (ratio * 10).round();
    final barText = _buildBarText(filledSegments); // '■■□□□...'

    return Column(
      // ...
    );
  }

  String _buildBarText(int filled) {
    const filled_ = '■';
    const empty_ = '□';
    return List.generate(10, (i) => i < filled ? filled_ : empty_).join();
  }
}
```

## 実装解説②: CompetitorFeatureComparisonCard

![Competitor Feature Comparison Card のスクリーンショット](https-::)

このカードは、競合との機能差を客観的に把握し、開発の優先順位を決めるための羅針盤です。

### UI の構築

`TabController` と `TabBar` を使って、Notion/Evernote/MoneyForward/X の4社を切り替えられるようにしています。中身は `ExpansionTile` のように展開・折りたたみが可能です。

### データ構造

各競合の機能リストは、`_FeatureRow` というクラスのリストとして静的に管理しています。実装ステータスは `_FeatureStatus` という `enum` で定義しており、これにより表示の出し分け（色、アイコンなど）を容易にしています。

```dart:lib/widgets/growth_roadmap_progress_card.dart
enum _FeatureStatus {
  done,       // 実装済み
  partial,    // 部分実装
  inProgress, // 開発中
  notYet,     // 未実装
  unique,     // 自分株式会社 独自機能
}

const _notionFeatureRows = <_FeatureRow>[
  _FeatureRow(
    category: 'ノート編集',
    feature: 'リッチテキスト編集',
    competitorDetail: 'Markdown + スラッシュコマンドでブロック挿入',
    status: _FeatureStatus.done,
    appDetail: 'Markdown 対応エディタ実装済み',
  ),
  // ...
];
```
このデータ構造のおかげで、機能カバー率の計算も `where()` と `length` を使うだけで簡単に実装できます。

```dart
int _doneCount(List<_FeatureRow> rows) =>
    rows.where((r) => r.status == _FeatureStatus.done).length;
```

## 実装解説③: 複雑なロジックを捌くホーム画面

ホーム画面のコアロジックは `home_page.dart` にあります。ここは、複数の `Future` を `FutureBuilder` で待ち受け、その結果を組み合わせてUIを構築するという、Flutterらしい非同期処理の塊です。

特に重要なのが、ユーザーに「次に何をすべきか」を提示するロジックです。

```dart:lib/pages/home_page.dart
// 運用スナップショットを非同期で構築
Future<_HomeOpsSnapshot> _loadOpsSnapshot() async {
    // SharedPreferences や複数の Supabase テーブルからデータを取得
    final monthlyCashflow = await _loadMonthlyCashflowSummary(...);
    final pendingCriticalTasks = await _fetchPendingCriticalTaskCount();
    // ...
    return _HomeOpsSnapshot(...);
}

// スナップショットを元に次にやるべきことを決定する
_HomeActionCommand _resolveNextAction(_HomeOpsSnapshot snapshot) {
    if (snapshot.abstinenceSlipCount > 0) {
      return const _HomeActionCommand(
        type: _HomeActionType.abstinenceGuard,
        title: '逸脱が発生。禁欲ガードを最優先',
        // ...
      );
    }
    if (!snapshot.morningBriefingDone) {
      return const _HomeActionCommand(
        type: _HomeActionType.morningBriefing,
        title: 'モーニング・ブリーフィングを先に実施',
        // ...
      );
    }
    // ...
    return const _HomeActionCommand(type: _HomeActionType.none, ...);
}
```

`_loadOpsSnapshot` でユーザーのあらゆる状態を非同期で集約し、その結果を `_resolveNextAction` が受け取って、優先度に基づき「次にすべきアクション」を一つだけ返す、という設計になっています。これにより、ユーザーは常に最も重要なことから着手できます。

## 今後の課題: Edge Function へのリファクタリング

現状のホーム画面は Flutter 側で多くの仕事をしすぎています。`_loadOpsSnapshot` を始めとするデータ集計処理は、クライアントの起動時に多数のDBアクセスを発生させ、パフォーマンスのボトルネックになりかねません。

そこで、我々は現在これらの処理を Supabase の **Edge Function** に移行する計画を進めています。

**計画: `get-home-dashboard` Edge Function の作成**

- **内容:** `_loadOpsSnapshot` や `_loadHomeKpiOverview` に相当する処理を、単一の Edge Function に統合します。
- **目的:**
  - クライアントからのリクエストを1回に集約し、初期表示を高速化する。
  - 複雑なロジックをバックエンドに集約し、フロントエンドのコードをシンプルに保つ。
  - Web/モバイルアプリ間でロジックを共通化する。

TypeScript で書かれた Edge Function は以下のようになります（イメージ）。

```typescript:supabase/functions/get-home-dashboard/index.ts
// ... (imports)

serve(async (req) => {
  const { userId } = await getUserFromRequest(req);

  // 複数のテーブルからデータを並列で取得
  const [
    monthlyCashflow,
    pendingTasks,
    dailyStatus,
    // ...
  ] = await Promise.all([
    fetchMonthlyCashflow(userId),
    fetchPendingTasks(userId),
    fetchDailyStatus(userId),
    // ...
  ]);

  // 取得したデータを元にサーバーサイドでロジックを実行
  const opsSnapshot = buildOpsSnapshot(...);
  const nextAction = resolveNextAction(opsSnapshot);

  // 整形したデータをクライアントに返す
  return new Response(
    JSON.stringify({ opsSnapshot, nextAction }),
    { headers: { "Content-Type": "application/json" } }
  );
});
```

このリファクタリングにより、フロントエンドは「データを取得して表示する」という本来の役割に、より集中できるようになります。

## おわりに

PMF前のプロダクト開発は、暗闇の中で手探りで進むようなものです。そんな中で、自分たちが作った「Growth Dashboard」は、暗闇を照らす灯台の役割を果たしてくれています。

この記事で紹介した機能は、すべて[成長戦略ロードマップ](https-::)という公開ドキュメントに基づいて開発しています。開発状況を徹底的に可視化し、ユーザーにも公開する "Build in Public" の思想は、僕のような個人開発者にとって、ユーザーを巻き込み、フィードバックを得て、何より開発のモチベーションを維持するための強力なエンジンです。

この記事が、同じようにFlutterとSupabaseでプロダクト開発に奮闘している方々の、何かしらのヒントになれば幸いです。

最後まで読んでいただきありがとうございました！
