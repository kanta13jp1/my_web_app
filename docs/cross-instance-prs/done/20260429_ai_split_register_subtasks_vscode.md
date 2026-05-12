# Cross-Instance PR: AI タスク分割 → 実 WBS 登録機能

**作成**: Win版#132 part 87 / 2026-04-29
**FROM**: Win版 (= User 要望一次受領)
**TO**: VSCode版 (`lib/pages/` Flutter UI 専任 territory)
**優先度**: HIGH (= production UX 改善 / 「分割しただけ」フェーズから「実行可能」フェーズへ)
**期限**: 2026-05-13 (2 週間)
**親軸**: IMBUE (UX) / VIBE_CODING #4 (Black-Box I/O Verification) / PHILOSOPHY #5 (商品=ユーザー価値)

---

## 1. ユーザー要望

> 「タスク分割ボタンをおすとただ分割した内容が表示されるだけでなく、実際にユーザータスクを実施可能な細分化したタスクとして登録するところまでやってもらえますか？」

= 現状の AI タスク分割 modal は **表示のみ**. → **実 WBS 登録** までやり切る.

screenshot 添付 (= /wbs-user-tasks / Issue #931 [CI失敗] Blog Draft Register / 3 subtask 表示中).

## 2. 現状動作

`lib/pages/user_tasks_page.dart` の `_AiAssistDialog` (= line ~760+):
- onBreakdown → AI から `subtasks: [{title, description, completion_criteria, estimated_minutes}]` 取得
- Modal 表示: `_subtasksSection` で 3+ 件の subtask カード描画
- アクション: `閉じる` ボタンのみ (= Navigator.pop)

= **AI が subtask 列挙するが DB に登録されない** = 1 click で実行可能化できない.

## 3. 期待する実装

### 3.1 「タスクを登録」ボタン追加

modal の actions に **「全部登録 (N 件)」** ボタン追加:

```dart
actions: [
  TextButton(
    onPressed: () => Navigator.pop(context),
    child: const Text('閉じる'),
  ),
  if (isBreakdown && subtasks.isNotEmpty)
    FilledButton.icon(
      icon: const Icon(Icons.add_task, size: 16),
      label: Text('全部登録 (${subtasks.length} 件)'),
      onPressed: _isRegistering ? null : () => _registerAllSubtasks(context, subtasks),
    ),
],
```

### 3.2 `_registerAllSubtasks` 関数新規

```dart
Future<void> _registerAllSubtasks(BuildContext context, List<Map<String, dynamic>> subtasks) async {
  setState(() => _isRegistering = true);
  int success = 0, failed = 0;
  final List<String> errors = [];

  for (var i = 0; i < subtasks.length; i++) {
    final s = subtasks[i];
    try {
      await Supabase.instance.client.functions.invoke('tools-hub', body: {
        'action': 'wbs.add_task',
        'category': parentTask.category,         // = 親 task 継承
        'category_icon': parentTask.categoryIcon,
        'category_order': parentTask.categoryOrder,
        'title': '${parentTask.title} :: ${s['title']}', // = 親 :: subtask 形式
        'description': _buildSubtaskDescription(s),
        'instance': parentTask.instance,
        'owner_instance': parentTask.ownerInstance,
        'priority': parentTask.priority,
        'status': 'pending',
        'progress': 0,
        'milestone_code': parentTask.milestoneCode,
      });
      success++;
    } catch (e) {
      failed++;
      errors.add('${i + 1}. ${s['title']}: $e');
    }
  }

  if (!mounted) return;
  setState(() => _isRegistering = false);

  // SnackBar で結果表示
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(
      failed == 0
        ? '✅ $success 件のサブタスクを登録しました'
        : '⚠ $success 件成功 / $failed 件失敗\n${errors.join('\n')}',
    ),
    duration: Duration(seconds: failed == 0 ? 3 : 8),
  ));

  // 成功なら modal close + WBS list 再読込
  if (failed == 0) {
    Navigator.pop(context);
    _refreshTasks();  // = 親 widget の reload
  }
}
```

### 3.3 description 構築

```dart
String _buildSubtaskDescription(Map<String, dynamic> s) {
  final parts = <String>[];
  final desc = _aiText(s['description']);
  final criteria = _aiText(s['completion_criteria']);
  final minutes = s['estimated_minutes'];

  if (desc.isNotEmpty) parts.add(desc);
  if (criteria.isNotEmpty) parts.add('完了条件: $criteria');
  if (minutes != null) parts.add('目安: $minutes 分');
  parts.add('---');
  parts.add('親タスク: ${parentTask.title}');
  parts.add('AI 分割で自動登録 (= ${DateTime.now().toIso8601String().substring(0, 16)})');

  return parts.join('\n\n');
}
```

### 3.4 個別登録ボタン (= 任意 / Phase 2)

各 subtask カードに「このタスクだけ登録」mini ボタン (= 選択的登録 UX). Phase 1 では「全部登録」のみ.

## 4. EF action は既存 reuse

`tools-hub:wbs.add_task` 既存 action (= line 3240+ in `supabase/functions/tools-hub/index.ts`) で対応可能:
- 必須: category / title / instance / owner_instance
- 任意: description / priority / status / progress / milestone_code / etc

→ **EF 改修不要** = VSCode 単独 territory で完結.

## 5. 受入基準

- [ ] modal に「全部登録 (N 件)」ボタン追加
- [ ] `_registerAllSubtasks` 関数: 全 subtask を順次 `wbs.add_task` で登録
- [ ] title 形式: `親タスク :: subtask タイトル` (= 親識別)
- [ ] description: subtask description + completion_criteria + estimated_minutes + 親 task 名 + 登録 timestamp
- [ ] instance / owner_instance / category / priority / milestone_code は親 task から継承
- [ ] 成功時: SnackBar + modal close + WBS list 再読込
- [ ] 失敗時: SnackBar に件数 + error details 表示 / modal は閉じない (= retry 可能)
- [ ] `_isRegistering` state で multi-click 防止
- [ ] integration_test: 1 シナリオ (= modal open → 全部登録 → SnackBar 表示確認 / VIBE #5 準拠)
- [ ] flutter analyze 0 エラー

## 6. UX 詳細 (= IMBUE 観点)

| 状態 | 表示 |
| --- | --- |
| ボタン idle | `[全部登録 (3 件)]` (= primary color) |
| 登録中 | `[登録中... (1/3)]` + spinner / disabled |
| 完了 success | SnackBar `✅ 3 件のサブタスクを登録しました` (= 3s) → modal close + reload |
| 完了 partial fail | SnackBar `⚠ 2 件成功 / 1 件失敗` + error 詳細 (= 8s) / modal stays open |

## 7. 連携軸

| 軸 | 連携 |
| --- | --- |
| **IMBUE** (UX 体験) | 「分割」→「登録」を 1 click で完了 = 摩擦ゼロ |
| **VIBE_CODING #4** (I/O Verification) | merge 判定 = modal 操作 + WBS タスク数増加で I/O 確認 |
| **VIBE_CODING #5** (Minimal E2E) | integration_test 1 シナリオで判定 |
| **PHILOSOPHY #5** (商品=ユーザー価値) | AI 出力を即実行可能化 = ユーザー価値最大化 |
| **PHILOSOPHY #6** (資本=時間) | 手動 task 登録 = 時間浪費 → 1 click 自動化 |

## 8. Phase 2 候補

- 個別登録ボタン (= subtask カードごとの mini button)
- `parent_task_id` カラム追加 + 親子関係 visualization (= /project-gantt 階層表示)
- AI 分割の **再生成 + 登録** (= 「分割が悪い / 再分割」UX)
- subtask 登録時の dependency 自動設定 (= subtask N+1 が N に depends_on)

= Phase 2 = schema 変更含むため別 cross-instance-pr で起票.

## 9. OPS-28 charter §6 受領 lane (= 本日 Win → VSCode lane 6 件目)

| part | from | to | 内容 | 状態 |
| --- | --- | --- | --- | --- |
| 58 | PS#5→Win | VSCode | js_interop reroute | ✅ |
| 62 | User→Win | VSCode | AIシェアモーダル | ✅ |
| 63 | User→Win | VSCode | horse_racing Tooltip | ✅ |
| 65 | Win | VSCode | AI_VIDEO #5 UI バッジ | ✅ |
| 82 | User→Win | VSCode | column resize | ✅ (Win 直接実装で完結) |
| **87 (本)** | **User→Win** | **VSCode** | **AI 分割 → 実登録** | **⏳ 起票** |

= Win → VSCode lane 6 件目. on-call routing + UX 改善混合.

## 10. 推奨実装順序

1. (1h) `_registerAllSubtasks` + `_buildSubtaskDescription` 関数追加
2. (30 分) modal actions に「全部登録」ボタン追加 + state 管理
3. (30 分) SnackBar + modal close + reload 実装
4. (30 分) integration_test 追加
5. (15 分) flutter analyze + dart format + commit + push

= **約 3 時間** で Phase 1 完成想定.

---

*Win版#132 part 87 / 2026-04-29 起票 / User 要望「AI 分割 → 実登録」/ VSCode 単独 territory (= EF 既存 reuse) / 既存 wbs.add_task action 利用 / 本日 Win → VSCode lane 6 件目*
