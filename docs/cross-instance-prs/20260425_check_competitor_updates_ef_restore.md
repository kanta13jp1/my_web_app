# Cross-Instance PR: check-competitor-updates EF 復旧

**発行**: PS版#4 S40 / 2026-04-25 午後
**宛先**: PS版#5 (on-call バグ修正)
**優先度**: 🟠 MEDIUM
**期限**: 2026-04-30

---

## 問題

`supabase/functions/check-competitor-updates/` ディレクトリが存在しない。

**確認方法**:
```bash
ls supabase/functions/ | grep competitor
# 出力なし
```

PS#6 S35 (EF 85→50 cleanup / commit b4c91bc2) で誤って削除された可能性が高い。

## 影響

- CLAUDE.md の EF一覧に記載 → 実際には存在しない → 404
- GHA schedule タスク `check-competitor-updates` が毎回失敗中
- 競合21社の可用性チェックが機能していない

## 復旧方針 (2択)

### Option A: 新規 EF として再作成 (推奨)

```typescript
// supabase/functions/check-competitor-updates/index.ts
// 競合21社のURL可用性チェック → Supabase に結果保存

const COMPETITORS = [
  { name: 'notion', url: 'https://notion.so' },
  { name: 'evernote', url: 'https://evernote.com' },
  { name: 'moneyforward', url: 'https://moneyforward.com' },
  { name: 'slack', url: 'https://slack.com' },
  { name: 'chatwork', url: 'https://chatwork.com' },
  // ... 全21社
];

// 各URLに HEAD request → status code 記録
// 結果を competitor_status テーブルに upsert
```

### Option B: admin-hub か tools-hub の action として統合

```
POST /functions/v1/admin-hub
{ "action": "competitor.check_availability" }
```

→ EF cap ≤ 50 維持のため Option B を推奨

## 優先度判断

- 競合モニタリングのコア機能 → 🟠 MEDIUM (バグ修正)
- ただし手動モニタリング (PS#4) で代替中 → blocking ではない

---

*PS版#4 S40 発行 / PS版#5 対応後に DONE でマーク*
