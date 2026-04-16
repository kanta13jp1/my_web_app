# Cross-Instance PR: クォータ監視ダッシュボード UI + admin-hub EF

**発行**: PowerShell版 (2026-04-16)  
**宛先**: VSCode版 (lib/ + supabase/functions/ 担当)  
**優先度**: 中 (フォールバック体制の可視化UI)  
**依存**: `ai_quota_usage` テーブル完成済み (migration: `20260416130000_create_ai_quota_usage.sql`)

---

## 1. admin-hub EF に quota.* アクション追加

**ファイル**: `supabase/functions/admin-hub/index.ts`  
**参考パターン**: `monitoring.get` (line 192) / `monitoring.record` (line 197)

既存の `case "monitoring.record":` の **後** に以下3アクションを追加:

```typescript
case "quota.latest": {
  // 各toolの最新レコードを取得 (dashboard用)
  const { data, error } = await admin
    .from('ai_quota_usage')
    .select('tool, checked_at, usage_json, alert')
    .order('checked_at', { ascending: false })
    .limit(20);
  if (error) return json({ error: error.message }, 500);
  // toolごとに最新1件のみ返す
  const latest = new Map<string, unknown>();
  for (const row of (data ?? [])) {
    if (!latest.has(row.tool)) latest.set(row.tool, row);
  }
  return json({ success: true, data: Array.from(latest.values()) });
}

case "quota.list": {
  // 履歴表示 (デフォルト30日)
  const days = Number(body.days ?? 30);
  const since = new Date(Date.now() - days * 86400_000).toISOString().slice(0, 10);
  const { data, error } = await admin
    .from('ai_quota_usage')
    .select('*')
    .gte('checked_at', since)
    .order('checked_at', { ascending: false });
  if (error) return json({ error: error.message }, 500);
  return json({ success: true, data });
}

case "quota.alert": {
  // 今日アラート中のtool一覧
  const today = new Date().toISOString().slice(0, 10);
  const { data, error } = await admin
    .from('ai_quota_usage')
    .select('tool, usage_json, alert')
    .eq('alert', true)
    .eq('checked_at', today);
  if (error) return json({ error: error.message }, 500);
  return json({ success: true, data });
}
```

---

## 2. Flutter クォータダッシュボードページ新規作成

**ファイル**: `lib/pages/admin/quota_dashboard_page.dart` (新規)

### 仕様

- `StatefulWidget` + `SupabaseClient? supabaseClient` DI コンストラクタ (admin_analytics_page.dart と同パターン)
- `initState` で `admin-hub` に `{"action": "quota.latest"}` POST
- 4ツール (anthropic / openai / github_copilot / gemini) のカードを表示:
  - ツール名 + ステータスアイコン: 🟢(alert=false) / 🔴(alert=true)
  - 使用量表示: `usage_json["cost_usd"]` / `usage_json["tokens"]` など
  - 最終チェック日: `checked_at`
  - プログレスバー: Claude $50 / OpenAI $20 を100%として計算
- アラート発生中の場合: 「フォールバック推奨」バナー + ファイル種別対応表
  - `.dart` → Gemini Code Assist
  - `.py` / `.ts` → CODEX CLI
  - `.yml` / `.sql` / `.md` → GitHub Copilot
- 手動更新ボタン: `admin-hub` の `quota.latest` を再呼び出し (reload)
- 展開可能な履歴テーブル: `quota.list` で30日分

### デザイントークン (docs/DESIGN.md 準拠)
- 背景: `0xFF0A0A0A`
- カード: `0xFF1A1A2E`
- アクセント: `0xFFFF6B35` (orange)
- アラート色: `0xFFFF4444`
- 正常色: `0xFF44BB88`

---

## 3. admin_analytics_page.dart にナビゲーションカード追加

**ファイル**: `lib/pages/admin_analytics_page.dart`

既存カードリストの先頭に追加:

```dart
// import追加
import 'admin/quota_dashboard_page.dart';

// ナビゲーションカード (既存カードと同パターン)
Card(
  color: const Color(0xFF1A1A2E),
  child: ListTile(
    leading: const Icon(Icons.monitor_heart, color: Color(0xFFFF6B35)),
    title: const Text('AI クォータ監視',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    subtitle: const Text('Claude / OpenAI / Gemini / Copilot の使用状況',
        style: TextStyle(color: Colors.white70)),
    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
    onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const QuotaDashboardPage())),
  ),
),
```

---

## 4. main.dart ルート追加

**ファイル**: `lib/main.dart`

```dart
// import追加
import 'pages/admin/quota_dashboard_page.dart';

// routes に追加
'/quota-dashboard': (_) => const QuotaDashboardPage(),
```

---

## 完了チェックリスト

- [ ] `deno lint supabase/functions/admin-hub/` → 0エラー
- [ ] `flutter analyze` → 0エラー
- [ ] `/quota-dashboard` ページが表示される
- [ ] `admin_analytics_page.dart` から遷移できる
- [ ] 4ツールのカードが表示される (データがなければ「データなし」表示)

完了後: このファイルに `✅ 完了 (VSCode版#XX YYYY-MM-DD)` を追記してください。
