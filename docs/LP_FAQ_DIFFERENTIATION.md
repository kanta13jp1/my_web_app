# LP 差別化 FAQ テキスト (vs Notion / Slack)

**用途**: LP実装時にFAQセクションへ組み込む差別化コピー。  
**作成**: PS#2 S34 cross-instance-pr `20260425_vscode_to_ps2_backend_assist.md` Task 3  
**実装先**: `lib/pages/landing_page.dart` (VSCode版 handoff)

---

## FAQ: 「すでに Notion + Slack を使っています。なぜ必要ですか？」

**Q:** すでに Notion + Slack を使っています。なぜ自分株式会社が必要ですか？

**A:** Notion はチームのナレッジを整理します。Slack はチームとのコミュニケーション。しかし「あなた自身の意思決定」「昨日の自分との比較」「人生のバランスシート」を管理するツールは存在しません。自分株式会社はその空白を埋めます。

---

## vs Notion 比較メッセージ

> Notion があなたのチームを助けるなら、自分株式会社はあなた自身の「CEO」を育てます。

| 自分株式会社 | Notion |
|---|---|
| 「昨日の自分」KPI | チーム向けナレッジ管理 |
| CEO感 (意思決定OS) | コラボツール |
| 資産/負債バランスシート | プロジェクト管理 |
| IPO/ウェルビーイング目標 | ゴール設定なし |

---

## ヒーロー文言案

「NotionでもSlackでもない、あなた自身のCEOオフィス。」

---

## 実装メモ (VSCode版向け)

- FAQ の `q/a` を `landing_page.dart` の `_faqItems` リストに追加
- 比較テーブルは既存の `ComparisonSection` widget を流用可
- DESIGN.md トークン適用必須 (`dart format` + `flutter analyze 0`)
