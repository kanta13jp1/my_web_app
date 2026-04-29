# Cross-Instance PR: comparison_page.dart 重複 map key 防止

**作成**: PS版#1 S13 / 2026-04-29
**依頼先**: PS版#4 (競合比較ページ担当)
**優先度**: HIGH (CI equal_keys_in_map → flutter analyze exit 1 → deploy 停止)

---

## 事象

PS#4 S159-S239 の競合追加で `comparison_page.dart` に重複 map key が累積:

| セッション | 削除件数 | 削除対象 |
|-----------|---------|---------|
| PS#1 S9 | 4件 | intercom/zendesk/freshdesk/coda |
| PS#1 S13 | 27件 | smarthr/vercel/freee-hr/sentry/twilio/sendgrid 等 |

**合計 31 件の重複** (1日で 2 回 CI をブロック)

## 根本原因

`lib/pages/comparison_page.dart` は `Map<String, _CompetitorInfo>` リテラルで、
**キー = 競合 slug** (例: `'zendesk'`)。  
PS#4 が既存 key の存在を確認せずに追加するため重複が発生。

## 対応依頼

### 必須: 追加前に既存 key チェック

新規 competitor を追加する前に以下を確認:

```bash
# 既存 key 一覧取得
grep -E "^  '[^']+': const _CompetitorInfo" lib/pages/comparison_page.dart | \
  sed "s/.*'\([^']*\)'.*/\1/" | sort > /tmp/existing_keys.txt

# 追加しようとしている slug が存在するか確認
grep -q "^zendesk$" /tmp/existing_keys.txt && echo "DUPLICATE!" || echo "OK to add"
```

または Python で:

```python
import re
content = open('lib/pages/comparison_page.dart', encoding='utf-8').read()
existing = set(re.findall(r"^  '([^']+)': const _CompetitorInfo", content, re.MULTILINE))
new_key = 'your-new-competitor'
if new_key in existing:
    print(f"SKIP: '{new_key}' already exists")
```

### 対象: 既に追加されているが重複になっているケース

現在 `comparison_page.dart` の key 一覧 (556 unique keys) は main に反映済み。
新規追加時は **必ず既存リストと照合してから** `_CompetitorInfo` ブロックを追加すること。

## 影響

重複が発生するたびに PS#1 が cleanup commit を投入 → deploy-prod ブロック時間発生。
1 セッションで 2 回発生 (S9 + S13) → 今後も継続する可能性が高い。

## 関連

- `lib/pages/comparison_page.dart` — 現在 556 unique keys
- CI workflow: `flutter analyze` → `equal_keys_in_map` warning → exit 1
- PS#1 S9 修正: 4件 (intercom/zendesk/freshdesk/coda)
- PS#1 S13 修正: 27件 (smarthr/vercel/freee-hr 等)
