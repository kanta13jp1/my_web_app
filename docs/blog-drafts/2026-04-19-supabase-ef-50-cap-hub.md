---
title: "Supabase Edge Functionを50本以下に維持する — hub統合アーキテクチャの設計"
tags: Supabase,Flutter,個人開発,buildinpublic,architecture
published: true
---

# Supabase Edge Functionを50本以下に維持する

## なぜ50本制限が必要か

Supabase には Edge Function の **デプロイ上限** がある。
無料プランでは制限が厳しく、有料プランでも無制限ではない。

```yaml
# deploy-prod.yml の自動チェック
- name: Check Edge Function deploy count
  run: |
    count=$(ls supabase/functions/ | wc -l)
    if [ "$count" -gt 50 ]; then
      echo "❌ EF数が上限を超えています: ${count}本"
      exit 1
    fi
    echo "✅ EF数: ${count}/50本"
```

CI がデプロイ前に自動チェックする。50本を超えたらデプロイ失敗。

## hub パターン: 複数機能を1つのEFに統合

```
# ❌ 機能ごとにEFを作ると爆発する
get-user-profile/
update-user-profile/
delete-user-profile/
get-user-settings/
update-user-settings/

# ✅ hub で統合
core-hub/  ← action パラメータで振り分け
```

```typescript
// core-hub/index.ts
const { action, ...params } = await req.json();

switch (action) {
  case "user.get_profile":    return getUserProfile(params);
  case "user.update_profile": return updateUserProfile(params);
  case "user.delete":         return deleteUser(params);
  case "settings.get":        return getSettings(params);
  case "settings.update":     return updateSettings(params);
  default:
    return new Response(JSON.stringify({ error: "unknown action" }), { status: 400 });
}
```

1つの EF が複数の action を処理 → EF 数を増やさずに機能を追加できる。

## 現在の hub 構成 (16本)

| EF名 | action 例 |
|------|-----------|
| `core-hub` | user, settings, notifications |
| `growth-hub` | goals, habits, streaks |
| `ai-hub` | tags.suggest, notes.bulk_summarize, notes.balance_review |
| `admin-hub` | users, analytics, reports |
| `app-hub` | dashboard, features, releases |
| `schedule-hub` | reminders, reports, digests |
| `tools-hub` | search, export, import |
| `media-hub` | upload, resize, cdn |
| `enterprise-hub` | teams, roles, billing |
| `social-commerce-hub` | posts, likes, products |
| `lifestyle-hub` | health, finance, calendar |
| standalone × 5 | 専用機能 |

**合計: 16本** (最大 50本の余裕 34本)

## 新機能追加の判断フロー

```
新機能が必要 →
  既存 hub に action 追加できるか?
    Yes → hub に追加 (EF数増えない)
    No  → 既存 EF を統合してスロット確保 → 新 EF 作成
```

```bash
# 現在のEF数を確認
ls supabase/functions/ | wc -l

# 50本近い場合: 統合候補を探す
ls supabase/functions/ | grep -v hub | head -20
# standalone EFが多い場合は hub に合流を検討
```

## Flutter 側: hub 呼び出しパターン

```dart
// 全ての AI 機能は ai-hub 経由
Future<List<String>> _suggestTags(String text) async {
  final response = await Supabase.instance.client.functions.invoke(
    'ai-hub',
    body: {'action': 'tags.suggest', 'text': text},
  );
  return List<String>.from(response.data['tags'] ?? []);
}

Future<List<Map>> _bulkSummarize(List<Note> notes) async {
  final response = await Supabase.instance.client.functions.invoke(
    'ai-hub',
    body: {
      'action': 'notes.bulk_summarize',
      'notes': notes.map((n) => {'id': n.id, 'content': n.content}).toList(),
    },
  );
  return List<Map>.from(response.data['summaries'] ?? []);
}
```

エンドポイントURLは `ai-hub` だけ覚えれば良い。action パラメータで機能を選ぶ。

## hub 統合のメリット/デメリット

| 項目 | hub統合 | 個別EF |
|------|--------|--------|
| EF数 | 少ない | 多くなりがち |
| デプロイ時間 | hub全体を再デプロイ | 個別EFだけ |
| コードサイズ | 1ファイルが大きくなる | 小さく分離 |
| デバッグ | action特定が必要 | エンドポイントが明確 |
| 追加コスト | action追加だけ | 新EF作成が必要 |

個人開発の規模では **hub統合がベスト**。
大規模チームでは個別EFで担当を分けるメリットがある。

## まとめ

50本ハードキャップは「設計の規律」として機能している。
制約があることで「本当に新しいEFが必要か？」を毎回問い直せる。
結果として hub パターンが定着し、コードが整理された状態を維持できる。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Supabase #Flutter #buildinpublic #architecture #個人開発
