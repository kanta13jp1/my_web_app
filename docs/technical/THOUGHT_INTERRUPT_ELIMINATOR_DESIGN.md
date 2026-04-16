# 思考妨害排除機能 設計書

## 概要

自分の思考をぶった切ってくる「邪魔」を特定して排除する機能。
既存の禁欲ガード (`abstinence_guard_page.dart`) を拡張し、
**パターン認識** + **AI診断** + **リアルタイム介入** を追加する。

## 現状 (既に実装済み)

`AbstinenceGuardStore` に以下のプリセットが存在:

| ID | ラベル | カテゴリ |
|----|--------|----------|
| sns | SNS | デジタル |
| mobile_games | スマホゲーム | デジタル |
| video | 動画 | デジタル |
| manga | 漫画 | デジタル |
| smartphone | スマホ | デジタル |
| masturbation | マスターベーション | 衝動 |
| smoking | 煙草 | 衝動 |
| alcohol | 酒 | 衝動 |
| lust | 性欲 | 衝動 |
| dating_apps | 出会い・異性探索 | 衝動 |
| gambling | ギャンブル | 衝動 |
| eating_out | 外食 | 衝動 |
| touch_hair | 髪をさわる | 癖 |
| touch_beard | 髭をさわる | 癖 |

## 追加すべき機能

### 1. 思考妨害パターン診断 (新規)

ユーザーに以下の質問をして、最大の思考妨害要因を特定する:

```
Q1: 集中が途切れた時、最初に何をしますか？
  → SNS / ゲーム / 動画 / 漫画 / スマホを手に取る / 食べ物を探す

Q2: 作業中に衝動が来た時、何をしたくなりますか？
  → タバコ / 酒 / オナニー / 出会い系 / ギャンブル / 間食

Q3: 1日のうち、最も集中が途切れやすい時間帯は？
  → 朝 / 昼食後 / 午後 / 夕方 / 夜 / 深夜

Q4: 集中が途切れる前に気づく「サイン」はありますか？
  → 手が無意識に動く / 目が泳ぐ / 姿勢が崩れる / あくびが出る / 何も感じない
```

結果から「あなたの最大の思考妨害」を特定し、禁欲ガードの該当項目を自動有効化。

### 2. リアルタイム介入ウィジェット (新規)

ホーム画面に「今この瞬間の妨害を排除」ボタンを追加:

```
🛡️ 思考妨害を排除
今の衝動: [SNS] [ゲーム] [動画] [オナニー] [タバコ]
↑ タップで即座に排除アクションを表示
```

タップすると、該当の `eliminationAction` と `replacementAction` を表示し、
slip をカウントする。

### 3. 週次パターンレポート (新規)

slip データから週次パターンを分析:
- 最も slip が多い曜日
- 最も slip が多い時間帯 (要: slip時のタイムスタンプ記録)
- 連続防衛日数 (streak)
- 改善トレンド

### 4. AI による介入提案

`ai-assistant` Edge Function を使い、slip パターンから
パーソナライズされた介入策を生成:

```
「あなたは金曜の夜にSNSとオナニーのslipが集中しています。
 金曜18時以降はスマホを別室に置き、
 代わりに本を1章読む習慣に置き換えることを提案します。」
```

## データベース変更 (マイグレーション)

### abstinence_slips テーブル (新規)

```sql
CREATE TABLE IF NOT EXISTS abstinence_slips (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id),
  item_id text NOT NULL,
  slipped_at timestamptz NOT NULL DEFAULT now(),
  context text,  -- 'morning' | 'afternoon' | 'night' | etc.
  trigger_note text,  -- ユーザーが入力する「何がきっかけだったか」
  created_at timestamptz NOT NULL DEFAULT now()
);
```

現状は SharedPreferences (ローカル) に保存しているが、
パターン分析にはサーバーサイドに移行する必要がある。

## 実装状況 (2026-04-16 更新)

| タスク | 担当 | 状態 |
|--------|------|------|
| `abstinence_slips` テーブル | Windows版 | ✅ 完了 (`20260411002400_create_abstinence_slips.sql`) |
| 思考妨害パターン診断UI (4質問) | VSCode版 | ✅ 完了 (`thought_interrupt_diagnosis_page.dart` + LP#78) |
| リアルタイム介入ウィジェット | VSCode版 | ✅ 完了 (`lib/widgets/thought_interrupt_quick_widget.dart`) |
| 週次スリップパターンレポート | VSCode版 | ✅ 完了 (`weekly_slip_report_page.dart` + LP#79) |
| AI 介入提案 (slip パターン渡し) | Web版 | 🟢 低優先度・未実装 |

## 実装担当 (参考)

| タスク | 担当 |
|--------|------|
| abstinence_slips テーブル | Windows版 (マイグレーション) |
| 禁欲ガードUI改善 | VSCode版 (lib/) |
| AI 介入提案 | Web版 (Edge Function) |
| 思考妨害診断UI | VSCode版 (lib/) |
