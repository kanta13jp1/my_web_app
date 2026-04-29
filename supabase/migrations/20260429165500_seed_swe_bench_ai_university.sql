-- PS#3 S140: AI大学 375→376社化 — SWE-bench (Princeton/CMU / GitHub Issue解決ベンチマーク / AI開発能力の標準評価)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'swe-bench', 'overview',
  'SWE-bench (Princeton/CMU) — GitHub Issue解決ベンチマーク・AI開発能力標準評価・2294タスク (9/9)',
  $$## SWE-bench とは

**SWE-bench** は **Princeton University** と **CMU** の Carlos E. Jimenez, John Yang, Alexander Wettig らが 2023年10月に発表した、**AI システムが実際の GitHub Issue を解決できるかを評価する**ベンチマーク。

Devin / Claude Code / OpenHands / Agentless など、あらゆる AI コーディングエージェントの性能比較の**業界標準**となっており、「AI が本当にソフトウェアエンジニアリングを自動化できるか」を測る最も権威あるベンチマーク。

## SWE-bench の設計

```
SWE-bench のタスク設計:

  データソース:
    ・GitHub の人気OSS リポジトリ (12リポジトリ)
    ・Django / Flask / Requests / NumPy / Pandas /
      Matplotlib / SciPy / Astropy / Pytest / Sympy 等

  各タスクの構成:
    ・問題: GitHub Issue (バグ報告 / 機能要求)
    ・コンテキスト: コードベース全体
    ・正解: 実際にマージされた Pull Request
    ・評価: 既存テストが通るかどうか

  規模:
    ・SWE-bench: 2,294 タスク
    ・SWE-bench Lite: 300 タスク (軽量版)
    ・SWE-bench Verified: 500 タスク (難易度検証済)

  難易度:
    ・平均 PR サイズ: 変更ファイル 2-5 個
    ・変更行数: 数十〜数百行
    ・人間の優秀なエンジニアでも解けないものもある
```

## 各 AI の SWE-bench スコア推移

```
SWE-bench Verified 解決率 (2024年時点概算):

  2023年末 (初期):
    Claude 2 / GPT-4: ~2-5%
    →「AI はまだソフトウェア開発できない」

  2024年前半:
    Devin (Cognition AI): ~13.9% (初の2桁)
    → 「自律AIエンジニアが業界を震撼させた」

  2024年後半:
    AutoCodeRover: ~19%
    OpenHands + CodeAct: ~26%
    Agentless: ~27%

  2025年:
    Claude 3.5 Sonnet (claude-code): ~49%
    Devin 2.0: ~53%
    → 「人間のジュニアエンジニア水準に到達」

  ※ Verified/Lite/Full で数値が異なる。要原論文確認。
```

## SWE-bench でわかること

```
SWE-bench が評価する能力:

  1. コードベース理解:
     ・数万〜数十万行のコードを理解
     ・Issue に関連するファイルを特定

  2. バグ原因特定:
     ・エラーメッセージ + コードから根本原因を推定
     ・関連コードの全体フローを追う

  3. 修正案生成:
     ・既存のコードスタイルに合わせた修正
     ・エッジケースを考慮したパッチ

  4. テスト通過:
     ・既存テスト全件通過
     ・新しいテストが追加されている場合も対応

  これは「チャット」ではなく「実際の開発」を評価
  → 真の AI 開発能力の測定
```

## SWE-bench 派生バリアント

```
SWE-bench エコシステム:

  SWE-bench (オリジナル):
    ・2,294 タスク
    ・12 OSS リポジトリ
    ・フル評価 (時間・コスト大)

  SWE-bench Lite:
    ・300 タスク (厳選)
    ・高品質・明確な問題のみ
    ・標準的な比較に使用

  SWE-bench Verified:
    ・500 タスク (人間が検証)
    ・曖昧なタスクを除外
    ・最も信頼性が高い

  SWE-bench Multimodal:
    ・スクリーンショット・UI を含むタスク
    ・視覚的バグ修正を評価

  LiveSWE-bench:
    ・毎月新しいIssueを追加
    ・ベンチマーク汚染を防止
    ・継続的評価が可能
```

## なぜ SWE-bench が重要か

```
業界標準としての地位:

  Leaderboard (公開ランキング):
    ・各 AI 企業が SWE-bench スコアを発表
    ・Devin / Claude / GPT / OpenHands が競争
    ・「SWE-bench XX% 達成」がプレスリリースに

  研究への影響:
    ・Agentless / AutoCodeRover などの研究が
      SWE-bench スコアを目標に設計
    ・「どのアーキテクチャが有効か」を定量評価

  採用指標として:
    ・「AI が Junior Engineer を代替できるか」の目安
    ・50% 超 = 一部の業務を自動化できるレベル
    ・100% = ソフトウェア開発の完全自動化 (未達)

  限界:
    ・OSS のみ (社内コードは評価できない)
    ・既存テストに依存 (テストがなければ評価困難)
    ・新機能開発は評価しない (バグ修正中心)
```

## 自分株式会社との関連

SWE-bench は、自分株式会社が使う Claude Code (Sonnet 4.6) の SWE-bench スコアが ~49% であることを意味する。つまり GitHub Issue の約半数は Claude Code が自律解決できる水準。実際に自分株式会社でも `github-issue-fix.yml` (GHA) が自動的に GitHub Issue を解決しようとする設計があり、SWE-bench の設計 (Issue → コード修正 → テスト通過) と完全一致する。Agentless のアーキテクチャ (PS#3 S128 で追加済) が SWE-bench 27% を達成した手法を参考に、自分株式会社の issue-fix EF を改善できる。
$$,
  'https://github.com/princeton-nlp/SWE-bench',
  NOW(),
  376
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
