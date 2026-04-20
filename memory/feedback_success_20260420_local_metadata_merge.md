---
name: Local metadata merge pattern for hub full-replace update
description: hub EF の goal.update など metadata を full-replace する action では、Flutter 側で既存 metadata を clone → 変更分 merge → spread 送信する
type: feedback
---

# Local metadata merge パターン

**Rule**: hub EF の update 系 action が metadata を full-replace で上書きする場合、単一 field のみ送信すると他 field が消失する。**Flutter 側で既存 metadata を clone → 変更分 merge → 全 metadata を body に spread 送信**する。

**Why**: PS#5 S27 (goal-tracker → tools-hub:goal.* migrate) で判明。
hub の `goal.update` は `updateItem(admin, id, { metadata: {...body} })` で metadata を full replace するため、`{'action': 'goal.update', 'id': goalId, 'status': 'completed'}` のような単一 field 送信だと title/description/deadline/milestones が全て消失する。

**How to apply**:
1. update 前に goal を lookup (`_findGoalById` helper 作成推奨)
2. 既存 metadata を `Map<String, dynamic>.from(goal['metadata'] as Map)` で clone
3. 変更分を merge (例: `meta['milestones'] = updated`)
4. 全 metadata を body に `...meta` spread:
   ```dart
   await _supabase.functions.invoke(
     'tools-hub',
     body: {'action': 'goal.update', 'id': goalId, ...meta},
   );
   ```

**適用候補 (要確認)**:
- 他の `*.update` hub action (reading.update / habit.update / poll.update 等) も同様の full-replace 設計なら同パターン適用

**逆に避けるべき**: hub 側で「merge にするために body の全 field を option にする」設計。EF 複雑化 + [EF-CAP-50] 圧迫。Flutter 側の一手間で済ませる方が hub シンプル維持。
