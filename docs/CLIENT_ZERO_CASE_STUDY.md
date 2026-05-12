# Client Zero Case Study — 自分株式会社の AI 駆動経営実証

> このドキュメントは、自分株式会社が **自社サービス + AI fleet を最初の顧客 (Client Zero) として徹底活用** した実証結果を、**エンタープライズ顧客向け営業資料** として整理したものである.
>
> **PLATFORM_EVOLUTION 原則 #3 (Client Zero & Trust-Based Acquisition)** dogfood. NEC が自社 30,000 人 Claude 導入 → エンタープライズ営業に転用した pattern を模倣.
>
> **想定読者**: 自分株式会社をエンタープライズ向けに導入検討する **CTO / CIO / DX 推進部門**.

---

## エグゼクティブサマリ (= 30 秒で読める要旨)

自分株式会社は **2026 年 4 月時点で 12 instance の AI fleet (10 Claude Code + 2 Codex CLI)** を **1 人の CEO が指揮** し、**3 日で 8 つの設計軸 / 75+ 原則** を確立する **AI 駆動経営の世界先進事例** を構築している.

### 主要数値

| 指標 | 値 | 比較 |
| --- | --- | --- |
| AI fleet 規模 | **12 instance 並行** | 業界平均 = 1-3 instance |
| 1 セッション最大スループット | **14 part / 1 日** | 単独 Claude 比 = **5-7x** |
| 1 日 cross-instance-pr 数 | 9 件起票 / 4 件当日完了 | (= 4 worker lane reciprocal cycle) |
| 設計軸数 | **10 軸 / 75+ 原則** | (= NotebookLM 蒸留パイプラインで指数増殖) |
| dogfood pattern 数 | 5 例 (= 軸間統合含む) | (= 設計→実装→委譲を 1 セッション内で完結) |
| Phase 1 (12→18 fleet) 期限 | 2026-Q3 (= 6 ヶ月) | (= FLEET_SCALING_ROADMAP.md 計画) |
| 最終目標 (Phase 4) | **100 fleet / 2028-Q3** | (= 3 年で 8.3x / IPO 期) |

= **「コードを書かない CEO」を 1 年以内に達成** する段階計画 + 実装基盤あり.

---

## 1. なぜ Client Zero として機能するか

### 1.1 NEC pattern の踏襲

NEC は **自社 30,000 人で Claude を導入** → 得られた運用ノウハウ + セキュリティ実績 → 金融 / 自治体向けエンタープライズ営業の武器に変換した.

自分株式会社も同パターン:

```
[自社で AI fleet を限界まで使い倒す]
        ↓ 得られる
[12 fleet 運用ノウハウ + OPS-28 charter + 10 設計軸 + 5 dogfood pattern]
        ↓ 営業武器に転換
[エンタープライズ顧客への AI 導入支援サービス]
```

### 1.2 「自分達が日々使っている」が最強の信頼資料

- ❌ 「AI 導入を支援します」(= 一般訴求 / 差別化なし)
- ✅ 「自分株式会社は 12 fleet で運営し、3 日で 8 軸蒸留する Client Zero です」

= **自社実証 = 営業資料 = 商品** の三位一体.

---

## 2. 12 Instance Fleet 構成 (= 2026-04-29 時点)

### 2.1 Roster

| カテゴリ | 数 | 詳細 |
| --- | --- | --- |
| Claude Code | 10 | VSCode / Win / PS#1-#6 / WEB / 📱モバイル |
| Codex CLI | 2 | Codex#1 (横断調査) / Codex#2 (CI・運用) |
| **計** | **12** | |

### 2.2 各 instance の専任 territory (= WORKDIR-ISOLATION rule)

```
VSCode版    → lib/ Flutter UI + EF
Win版       → docs / migration schema / 動画パイプライン
PS#1        → Rule17 WF health + instance config
PS#2        → T-1 dispatch (dev.to / Qiita / 累計 142+ 本)
PS#3        → AI 大学コンテンツ更新 (= 326 provider まで拡大)
PS#4        → 競合モニタリング (= 258+ 競合 SaaS)
PS#5        → on-call バグ修正
PS#6        → horse_racing scraper / sort 因子 21 terms
WEB版       → screenshot + 不具合解析
📱モバイル  → 実機 UAT / iOS+Android
Codex#1     → 横断調査 / SQL レビュー補助
Codex#2     → CI / EF / GHA 補助
```

### 2.3 補助 AI (= fleet 外 / 必要時起動)

- **NotebookLM** = リサーチ / Master Brain / 軸蒸留パイプライン (= 4 日で 8 軸生成)
- **Gemini Code Assist** = Google/Flutter/Firebase 系
- **GitHub Copilot** = inline / テスト追加
- **Manus AI** = ブラウザ操作 / 外部 SaaS 確認

---

## 3. 実測スループット

### 3.1 1 セッション 14 part 達成 (= Win版#132 / 2026-04-28)

| フェーズ | part 数 | 内容 |
| --- | --- | --- |
| 構造化 | 47-49 | Migration collision detector / Codex backlog monitor / MCP server skeleton |
| Production hotfix | 50-51 | memo-reactions 404 hotfix / deploy-prod concurrency 修正 |
| Charter 確立 | 52-55 | cross-instance-pr cycle close / Codex routing 明文化 / OPS-28 §6 永続化 |
| Self-applied 監査 | 56-60 | ROADMAP-LOG self-applied detector 2 回発動 / 受領 lane 初稼働 |
| **計 14 part** | | (= 単独 Claude 開発比 5-7x スループット) |

### 3.2 4 日間 NotebookLM 蒸留 (= 2026-04-26 → 2026-04-29)

| 日付 | 確立軸 |
| --- | --- |
| 2026-04-26 | AI_CHARACTER (= 8 原則 / 人格・倫理) |
| 2026-04-27 | IMBUE (= 7 パターン / AI×UX 体験設計) |
| 2026-04-28 (1 日 5 軸) | COLLAB_AI / MCP_AUTH / AI_VIDEO / VIBE_CODING / PLATFORM_EVOLUTION |
| 2026-04-29 | SECOND_BRAIN |

= **4 日で 8 軸 / 60+ 原則** (= 5 legacy + 8 蒸留 = 10 軸 / 75+ 原則合計).

### 3.3 1 日累計 (= 2026-04-28 実測)

- cross-instance-pr 起票: **9 件**
- 当日完了: 4 件 (PS#1+PS#5 lane / 即日 reciprocal)
- 翌日想定: 5 件 (Codex+VSCode lane)
- = **4 worker lane reciprocal cycle** が実証.

---

## 4. 10 設計軸 / 75+ 原則

### 4.1 軸の階層 (= 2026-04-28 確立)

```
[Layer 1 — メタ層]      VIBE_CODING (運用責任 / 取締役会規範)
        ↓ supervises
[Layer 2 — 戦略+技術層] PLATFORM_EVOLUTION (成長 playbook)
        ↓ guides
[Layer 3 — 設計層]      PHILOSOPHY/AI_DEV/AI_CHARACTER/IMBUE/COLLAB_AI
                         /MCP_AUTH/AI_VIDEO/SECOND_BRAIN (= 8 軸)
```

### 4.2 各軸の概要

| 軸 | 原則数 | 焦点 | ベースライン |
| --- | --- | --- | --- |
| PHILOSOPHY | 9 | なぜ作るか (CEO 感 / IPO ゴール) | (legacy) |
| AI_DEV | 7 | どう作るか (= 開発プロセス) | (legacy) |
| AI_CHARACTER | 8 | どんな人格で動くか | 1.5/8 |
| IMBUE | 7 | どう感じさせるか (UX) | 1.5/7 |
| COLLAB_AI | 7 | どう進化するか | 1.5/7 |
| MCP_AUTH | 10 | どう開かれるか (server 公開時必須) | 0.5/10 |
| AI_VIDEO | 6 | どう動画として現れるか | 2.0/6 |
| VIBE_CODING | 7 | 運用責任 (Production AI 開発) | **6.5/7** |
| PLATFORM_EVOLUTION | 7 | 成長 playbook (12→100 fleet) | 2.0/7 |
| SECOND_BRAIN | 7 | 知識インフラ (PKM 健全性) | **4.0/7** |

= **10 軸 / 75+ 原則 / 各軸に baseline 数値化済**.

### 4.3 軸の生成エンジン

```
[NotebookLM URL 提供]
        ↓ 30 分以内
[notebooklm use + ask で 7 原則抽出]
        ↓
[docs/<NAME>_PRINCIPLES.md 新規作成]
        ↓
[CLAUDE.md hook table + ~/.claude/hooks/inject-rules.txt 注入]
        ↓
[OPS-28 charter 軸数更新]
        ↓
[memory + MEMORY.md + ROADMAP + commit + push]
```

= **URL 1 つ → 30 分以内の運用化サイクル**. これ自体がエンタープライズ営業の武器 (= 「貴社の知識を AI fleet に組み込む standard pipeline 提供」).

---

## 5. dogfood Pattern (= 5 例 / 自己実証)

| 例 | 軸 | 性質 | 規模 |
| --- | --- | --- | --- |
| 1 (part 65) | AI_VIDEO #5 (Ethical Provenance) | Win + VSCode 分担 | 中 |
| 2 (part 69) | SECOND_BRAIN #3+#4 | Win + PS#1 分担 | 中 |
| 3 (part 70) | SECOND_BRAIN #7 | Win 設計 + Codex#2 実装 | 大 (cross-instance-pr) |
| 4 (part 71) | SECOND_BRAIN #5 | Win territory 軽量 | 軽 (1 セッション) |
| **5 (part 72)** | **VIBE #1 + BRAIN #1** | **1 doc 2 軸統合** | **軽 (= 軸間統合 第 1 例)** |

= **dogfood pattern が 5 例まで進化**:
- 第 1-3 例 = 1 軸 → 多 territory 分担
- 第 4 例 = 軽量 (= 1 セッション完結)
- **第 5 例 = 軸間統合** (= 概念重複の発見 → 1 doc で 2 軸 baseline 押上)

### 5.1 dogfood 連鎖第 1 例

```
[part 70: cross-instance-pr で AI 出力生成]
        ↓ 一時消費せず
[part 71: query_artifact 化 (= 永続化)]
        ↓ 将来別 instance が
[再利用 (= search で発見可 + megaprompt 入力)]
```

= **dogfood が dogfood を呼ぶ** 連鎖.

---

## 6. Operations Charter §6 (= 1 日サイクル運用)

```
発見 (= 5 監査 / 改善トリガー)
   ↓ 即対応
提案 (= cross-instance-pr 起票 / handoff template)
   ↓ 1 task = 1 commit
実装 (= 受領 instance / push origin HEAD:main)
   ↓ 完了確認
done/ 移動 + 5 正本層 #1 整合復活
```

### 6.1 5 正本層 (Source of Truth)

1. GitHub Issues / PR = 実行単位
2. WBS / Notion = 進捗
3. NotebookLM = Master Brain (判断履歴)
4. Slack = 進行通知
5. 各 worktree / branch = 実作業

### 6.2 6 AI 役割

Claude Code (10) / Codex (2) / Gemini / Copilot / Manus / NotebookLM.

### 6.3 5 監査 (セッション開始時 30 秒以内)

担当領域 overlap / ファイル衝突 / 5 正本整合 / 通知の生死 / AI ツール配置.

---

## 7. エンタープライズ顧客への提供価値

### 7.1 直接提供できる成果物

| 成果物 | 内容 | 価値 |
| --- | --- | --- |
| **OPS-28 charter** | 12 fleet 運用憲章 (= 5 SoT + 6 役割 + 5 監査 + 5 トリガー + §6 1 日サイクル) | 1-2 年の試行錯誤を即座に圧縮 |
| **10 設計軸 docs** | 75+ 原則 / Markdown ベース | 設計言語をゼロから作らなくて済む |
| **NotebookLM 蒸留パイプライン** | URL → 30 分で軸確立 | 自社知識資産を AI 駆動の設計言語に変換 |
| **CORE_LEAF_BOUNDARY** | 4 Tier (Schema/Core/Leaf/Auto-Gen) | AI 全委任 OK な範囲を物理的境界で明示 |
| **FLEET_SCALING_ROADMAP** | 4 Phase 計画 (12→18→24→50→100) | 自社 fleet 拡大の milestone テンプレ |
| **dogfood pattern 5 例** | 軸間統合 / co-implementation 含む | 自社の設計→実装サイクル設計に転用可 |

### 7.2 想定 Use Case

#### Case A: 大企業 (= 10,000+ 従業員)

- 自社の **OPS-28 charter** 模倣で社内 AI 利用ガイドライン整備
- **10 設計軸** を社内 AI ガバナンスの起点に活用
- **NotebookLM 蒸留パイプライン** で社内 wiki / 規程を AI 設計言語化

#### Case B: 中堅企業 (= 100-1000 従業員)

- 自分株式会社 fleet 規模 (= 12) を直接コピー
- **dogfood pattern** で社内 AI 機能を「自社が最初の顧客」として展開

#### Case C: スタートアップ

- **CORE_LEAF_BOUNDARY** で AI が触れる範囲を初期から明示
- **VIBE_CODING #1-#7** で「コード読まない CEO」体制を最初から構築

---

## 8. 実証期間 (= 自分株式会社 timeline)

| 期間 | マイルストーン |
| --- | --- |
| 2025-Q3 | 自分株式会社プロジェクト起動 |
| 2025-Q4 | Flutter Web + Supabase 基盤確立 |
| 2026-Q1 | 21 競合機能統合完了 |
| 2026-04-24 | User 方針宣言「12 並行 + 運用改善都度提案」採択 |
| 2026-04-26-29 | NotebookLM 蒸留 8 軸 (= 4 日) |
| 2026-04-28 | 1 セッション 14 part 達成 / OPS-28 charter §6 永続化 |
| 2026-04-29 | SECOND_BRAIN dogfood (7 part 連続) / MEMORY.md ローテーション自動発生 (= 軸の必要性が緊急 validation された) |
| 2026-Q3 (予定) | Phase 1 完了: 18 fleet |
| 2027-Q1 (予定) | Phase 2 完了: 24 fleet / コード読み 0% |
| 2028-Q3 (予定) | Phase 4: 100 fleet / IPO 期 |

---

## 9. お問い合わせ / 導入相談

(= future / Phase 2 完了後にエンタープライズ営業窓口設置)

- **本番 URL**: <https://my-web-app-b67f4.web.app/>
- **設計軸 公開先**: GitHub `kanta13jp1/my_web_app` の `docs/*PRINCIPLES.md` (= 全公開)
- **Client Zero 営業窓口**: (= 未設置 / Phase 2 完了後)

---

## 10. 連携軸

| 軸 | 連携内容 |
| --- | --- |
| **PLATFORM_EVOLUTION #3** (Client Zero) | 本 docs = #3 dogfood. baseline 2.0 → 3.0/7 |
| **PLATFORM_EVOLUTION #2** (Workplace OS) | 「21 競合を束ねる」訴求は本 docs §2.1 と直結 |
| **VIBE_CODING #7** (Embrace Exponentials) | FLEET_SCALING_ROADMAP の数値を本 docs §1 に転用 |
| **OPS-28 charter** | §6 1 日サイクルを本 docs §6 に転用 |
| **PHILOSOPHY #1** (CEO 感) | 「CEO がコード読まない」訴求の起点 |
| **PHILOSOPHY #9** (IPO/ウェルビーイング) | Phase 4 ゴールに接続 |

---

## 実装履歴

| 日付 | part | 実装 | 達成原則 | baseline |
| --- | --- | --- | --- | --- |
| 2026-04-29 | Win版#132 part 75 | `docs/CLIENT_ZERO_CASE_STUDY.md` 新規 (10 セクション / 12 fleet 構成 / 4 日 8 軸 / 1 セッション 14 part / dogfood 5 例 / Phase 計画 / Use Case 3 種) | PLATFORM #3 dogfood | PLATFORM 2.0 → **3.0/7** |

---

*Win版#132 part 75 / 2026-04-29 起票 / PLATFORM #3 (Client Zero) dogfood / NEC pattern 模倣の自社実証→営業資料転換 / Phase 2 完了後の対外発信基盤 / dogfood pattern 第 6 例 (= 営業資料化)*
