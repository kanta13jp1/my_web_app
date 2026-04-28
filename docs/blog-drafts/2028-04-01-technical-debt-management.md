---
title: "個人開発の技術的負債管理 — 借りていい負債と返すべき負債"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 個人開発の技術的負債管理 — 借りていい負債と返すべき負債

技術的負債を全部返そうとすると前に進めない。戦略的に付き合う。

## 負債の分類

```
借りていい負債 (Strategic)
  ├── MVP 検証前の仮実装
  ├── 将来的にリファクタできる分離済みコード
  └── ユーザー数が少ない間の性能妥協

返すべき負債 (Blocking)
  ├── テスト不能なモジュール結合
  ├── バグの再発を引き起こす構造
  └── チームの認知負荷を上げるもの (将来の自分含む)
```

## 負債を可視化する: `TODO` + `FIXME` 管理

```dart
// 借りている負債を明示的に記録する
// TODO(2028-Q2): Supabase RPC に移行 — Edge Function 化後
Future<List<Task>> getTasksHack(String userId) async {
  // FIXME: N+1 クエリになっている。件数増えたら RPC 化必須
  final tasks = await supabase.from('tasks').select().eq('user_id', userId);
  return tasks.map(Task.fromJson).toList();
}
```

**GHA で負債を定量化**:

```yaml
# .github/workflows/debt-audit.yml
- name: Count TODOs and FIXMEs
  run: |
    TODO_COUNT=$(grep -r 'TODO\|FIXME' lib/ --include='*.dart' | wc -l)
    echo "Technical debt items: $TODO_COUNT"
    echo "debt_count=$TODO_COUNT" >> $GITHUB_OUTPUT
```

## リファクタリングの優先順位付け

```
優先度 High:
  - バグが再発している箇所 (Issue に記録があるもの)
  - 変更頻度が高いのに理解が難しい箇所
  - 新機能追加を毎回ブロックする構造

優先度 Low:
  - 変更されない安定コード
  - テストが通っている動作中のコード
  - 外部からは見えない内部実装
```

## 段階的リファクタリング: Strangler Fig パターン

大きなリファクタは「一気に」やらない。並走させて段階的に切り替える。

```dart
// Before: 直接 Supabase 呼び出しが散在
class TaskPage extends StatefulWidget {
  Future<void> _loadTasks() async {
    final data = await supabase.from('tasks').select();  // 直接呼び出し
    setState(() => _tasks = data.map(Task.fromJson).toList());
  }
}

// Step 1: Repository 層を新設 (並走)
class TaskRepository {
  Future<List<Task>> getAll(String userId) async {
    final data = await supabase
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return data.map(Task.fromJson).toList();
  }
}

// Step 2: 新ページから新層を使い始める
// Step 3: 旧コードを削除 (テストが通ったら)
```

## 負債返済のリズム: 20% ルール

スプリント (週単位) の作業時間の **20%** を技術的負債の返済に充てる。

```
月曜: 新機能実装 (80%)
金曜: リファクタ / テスト追加 / TODO 処理 (20%)
```

これを守ることで、負債が雪だるま式に増えるのを防げる。

## GHA で自動リマインド

```yaml
# .github/workflows/weekly-debt-reminder.yml
on:
  schedule:
    - cron: '0 9 * * MON'  # 毎週月曜9時

jobs:
  remind:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: List top debt items
        run: |
          grep -rn 'FIXME\|TODO.*Q[1-4]' lib/ --include='*.dart' | head -10
```

## まとめ

```
分類する    → Strategic (借りていい) vs Blocking (返すべき)
可視化する  → TODO/FIXME + 期限コメント + GHA 定量化
優先順位    → バグ再発 > 変更頻度高 > 新機能ブロック
返済リズム  → 毎週 20% を負債返済に充てる
```

負債を「管理された借金」として扱う。無借金経営が目標ではない。
