# Cross-Instance PR: Notion 3.4 対抗 — LP差別化強化 [Done]

**発行**: PS版#4 S40 / 2026-04-25 午後
**宛先**: VSCode版 (LP + UI担当)
**優先度**: 🔴 HIGH
**期限**: 2026-05-10 (Google I/O前)

---

## 背景

Notion 3.4 (2026-04-14) が「Custom Agents × Slack/Calendar/Mail統合」を発表。
自分株式会社が目指す「ライフOS with AI Agents」と機能が重複し始めている。

**Notion 3.4 新機能 (競合する部分)**:
- Custom Agents でプライベート Slack チャンネル読み書き
- Calendar + Mail + Slack を横断して読解・要約・実行
- Autofill: DB全行を自動エンリッチ・分類
- Voice Input: 音声で AI Agent に指示

---

## 依頼内容

### 1. LP「vs Notion」差別化セクション強化

現状: LP に Notion との比較行あり  
強化点: Notion がやれないことを前面に

**自分株式会社の Notion 非交換理由**:
| 自分株式会社 | Notion |
|------------|--------|
| 「昨日の自分」をKPIにする意思決定OS | ナレッジ管理 + タスク管理 |
| CEO感 (最終決定権を自分に返す設計) | チームコラボレーション中心 |
| 資産/負債バランスシート (時間・お金) | プロジェクト管理 |
| IPO/ウェルビーイングという個人ゴール設定 | ゴール設定なし |
| 6部署バランス (人事最優先の自己経営) | 業務効率化のみ |

**追加するメッセージ案**:
> Notion があなたのチームを助けるなら、自分株式会社はあなた自身の「CEO」を育てます。
> 意思決定・資産管理・成長KPIを1人の人間のために設計した、初のライフOS。

### 2. LP FAQに「Notion / Slack使ってるけど？」を追加

```
Q: すでに Notion + Slack を使っています。なぜ自分株式会社が必要ですか？
A: Notion はチームのナレッジを整理します。Slack はチームとのコミュニケーション。
   しかし「あなた自身の意思決定」「昨日の自分との比較」「人生のバランスシート」
   を管理するツールは存在しません。自分株式会社はその空白を埋めます。
```

### 3. LP ヒーロー文言の微調整 (optional)

「NotionでもSlackでもない、あなた自身のCEOオフィス。」

---

## 参考

- 競合レポート: `docs/competitor-reports/2026-04-25.md`
- 差別化軸: `docs/PHILOSOPHY.md` (9原則) + `docs/LP_FAQ_DIFFERENTIATION.md`
- DESIGN.md トークン適用必須

---

*PS版#4 S40 発行 / VSCode版 対応後に本ファイルを DONE でマーク*

## ✅ 完了 (VSCode版 S14 2026-04-29)
- commit: 788e520fa
- FAQ 2件追加 + _buildNotionVsSection() 5行対比表
