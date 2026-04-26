# Cross-Instance PR: virtual_organization_page タスク割り振り機能 stub → 実装依頼

**起票**: PS版#5 S62 (2026-04-26)
**FROM**: PS版#5 (on-call bug fix)
**TO**: Win版 (ai-hub EF 追加) + VSCode版 (Flutter UI 更新)
**優先度**: low (UX改善)
**期限**: 2026-05-10

---

## 背景

`virtual_organization_page.dart` の「タスク割り振り」ボタンが、
`virtual-organization` EF削除後に `ai-hub:org.get` へ切り替え (PS#5 S61) したが、
`org.get` はタスク割り振りを行わないため、ボタンが **UXスタブ** (準備中メッセージのみ) になっている。

## 現状コード (PS#5 S62 適用後)

```dart
Future<void> _assignTask(String goal) async {
  // org.assign action は未実装 (org.get のみ利用可能)
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('タスク割り振り機能は準備中です')),
    );
  }
}
```

## Win版 対応依頼: ai-hub に `org.assign` action 追加

```typescript
case "org.assign": {
  const goal = asString(body.goal);
  if (!goal) return json({ error: "goal required" }, 400);
  // agent_config からランダムまたは最適なエージェントを選択
  const agents = await listItems(admin, "agent_config", userId!, 20);
  const assigned = agents[Math.floor(Math.random() * agents.length)] ?? null;
  // wbs_tasks or agent_tasks テーブルにタスクを INSERT
  await admin.from("wbs_tasks").insert({
    title: goal,
    description: `AI組織タスク: ${goal}`,
    instance: "ai-org",
    status: "pending",
    owner: assigned?.name ?? "AI組織",
    created_at: new Date().toISOString(),
  });
  return json({ success: true, assigned_to: assigned?.name ?? null });
}
```

## VSCode版 対応依頼: Flutter UI 更新

Win版が `org.assign` 実装後、以下に更新:

```dart
Future<void> _assignTask(String goal) async {
  try {
    final res = await _supabase.functions.invoke(
      'ai-hub',
      body: {'action': 'org.assign', 'goal': goal},
    );
    final assignedTo = res.data?['assigned_to'] as String? ?? 'AIエージェント';
    await _fetchOrganization();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('タスクを $assignedTo に割り振りました')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    }
  }
}
```

## 参考

- ai-hub `org.get` 実装: `supabase/functions/ai-hub/index.ts` L2809
- PS#5 S61 stale EF migrate: `docs/cross-instance-prs/20260420_ps5_flutter_stale_invoke_audit_24ef.md`
