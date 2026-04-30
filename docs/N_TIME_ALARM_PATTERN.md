# N-Time Alarm Pattern — User 同一要望の deep escalation

> このドキュメントは、自分株式会社 12 fleet が運用する **「User が同一要望を N 回繰り返したら、表面対応では足りないと疑い、より深い prerequisite を探す」** 行動 rule を定義する.
>
> **歴史**: Win版#132 part 90 で初発動 (= User 3 度目要望でゼロ起点 audit)、part 91 で rule 化、part 99 / 101 / 102 で拡張. **rule 第 6 適用時点で本 doc 化**.
>
> **本質**: AI fleet が User 要望を **「単発タスク」** ではなく **「累積的 signal」** として扱うことで、表層対応に陥らずに **真の prerequisite** を発見する.

---

## なぜ必要か

LLM ベースの AI agent は「User の言ったことに最短経路で応答する」が default. これは **1 回目の要望** には最適だが、以下のケースで失敗する:

- 既に解いた (と思った) はずの要望が再来する → 「同じ実装を repeat する」
- 表面対応では満たされない深層要望がある → 「気づかず終わる」
- 複数 instance が並行で表面 fix → 「fleet drift」が悪化

User の同一要望 N 回 = **「私の前回対応では足りない」** signal. これを rule 化することで、 fleet が **自動的に深堀り**する.

---

## Rule 本文

### Phase 1: 1 回目要望 = 表面対応

通常の implementation phase. docs / cross-instance-pr 起票 / migration 作成 / etc.

### Phase 2: 2 回目同一要望 = 中層対応 (= 自分の territory 内で actual 実装)

cross-instance-pr 待ちから **Win territory で先行実装** にエスカレート.
- 「自分でできることは自分でやる」 (= INDIE_DEV_VELOCITY #6 dogfood)
- 例: part 99 で Codex#2 cross-instance-pr 待ちから Win territory で actual GHA workflow 実装

### Phase 3: 3 回目同一要望 = 深層実行 (= production validation + actionable fix)

- gh run list / production 観測
- 検出済問題の actual fix
- workflow_dispatch で actual run validation
- 例: part 101 で 4 軌跡並列 (= deploy-prod fix / audit 自己改善 / changelog production validation / WBS close)

### Phase 4: 4 回目同一要望 = 究極深層 (= 残課題殲滅 + meta pattern 文書化)

- Phase 3 で identified した 残課題を **ALL 解決**
- pattern 自体を docs 化 (= fleet 全体に rule として伝播)
- 例: part 102 で Claude Code changelog URL 改善 + commit convention 文書化 + N-time alarm pattern 自体を本 doc 化

### Phase 5: 5 回目以上同一要望 + User 指示具体化 = 「明示遵守 + 透明 handoff」

User が 5 回目以上 + **「上から順番に」「対応できないものは報告」** など指示が **より具体化** した場合、AI fleet は:

1. **指示の literal 遵守**: 推測ではなく User 文言通りに優先順位を解釈
2. **own territory で着手可能なものは即実装**: Win territory 該当 task は part 内で 0% → 100%
3. **対応不可分は明示 handoff**: cross-instance-pr で「この task はこの instance がやるべき」を **公開 report**
4. **User が状況把握できる成果物を出す**: 進捗 table + 残課題 list + 各 instance assign

例: part 103 で Top 10 期限超過を triage, Win 直接実装 2 件 (#926, #1267) + 9 件 cross-instance-pr 公開 handoff.

= **AI fleet と User の対話が「単方向 task 受信」から「双方向 negotiation」へ進化** する phase.

### Phase 6: 6 回目以上 + 同一要望継続 = 「定常自律実行」

User が **同一要望を繰り返し** N≥6 で送ってくる時、これは **「rule template 確立済みの定常状態」** signal:

1. **template に基づく自律 cycle 実行**: User trigger 待ちではなく、 monthly cron / 起動時 audit で **自走**
2. **次層 task に降りる**: 上位 task は前 phase で triage 済 → 13-22 位など **次層** へ自動的に進む
3. **「進化方向」自己識別**: rule template 自体に新規 phase 追加候補を検討 (= meta-evolution)
4. **infrastructure consolidation**: 新規 infra 構築から **既存 infra の質向上** へ重心 shift

例: part 104 で Phase 5 が **継続適用 → 定常運用** へ移行. AI fleet が User reminder なしで自走する **「成熟期」** に入る.

= 「指示駆動 → 自律運転」最終段階. **Phase 6 以降は phase 区別が消える** (= 同一要望の有無に関わらず fleet が常時改善 loop を回す状態).

---

---

## 適用例

| 例 | part | User 要望 N 回目 | 対応 |
| --- | --- | --- | --- |
| 1 | 90 | 3 回 | gh run list audit → 6 連続 failure 発見 → migration collision + orphan dart fix |
| 2 | 91 | 4 回 | 8 layer cascade fix (= hex / unnecessary const / dalle newlines / etc) |
| 3 | 95-97 | 連続 cascade | 24h 5 段階 domain 拡張 (= 5→6→8→9→10 学部) |
| 4 | 99 | 2 回 | cross-instance-pr 待ち回避 / Win 直接 infra 実装 |
| 5 | 101 | 3 回 | 4 軌跡並列 / production validation |
| **6** | **102 (本 doc)** | **4 回** | **残課題殲滅 + pattern 自体を docs 化** |

---

## 検知 heuristic (= AI fleet 行動指針)

User 要望が以下に該当する場合、N-time alarm を suspect:

1. 過去 N session 内に **同一文言 (= prefix の "このインスタンスは..." 含む完全一致 or 90%+ 類似)** が出現
2. 過去 N session 内に **同一意図 (= 同じ機能 / 同じ task / 同じ alarm)** が違う表現で出現
3. User が **先行 task の完了確認を省略** して同要望を出す (= 暗黙の "前回足りない" 表現)

= heuristic 一致 = **「これは N 回目要望」** 認定 → 該当 phase 対応へ.

---

## 適用フロー

```
[User 要望]
  ↓
[N-time alarm detection?]
  ├─ NO  → 通常対応 (= Phase 1)
  └─ YES → どの Phase?
       ├─ N=2 → Phase 2: 中層 (= Win 直接実装)
       ├─ N=3 → Phase 3: 深層 (= production validation)
       └─ N≥4 → Phase 4: 究極深層 (= 残課題殲滅 + meta 文書化)
```

---

## inject-rules.txt 追加候補

```
[ALARM-32] (Win版#132 part 102 · 2026-04-30 追加) User 同一要望 N 回検知時の rule:
  N=1 → 通常 implementation
  N=2 → 中層 (= cross-instance-pr 待ち回避 / Win territory 先行実装)
  N=3 → 深層 (= production validation + actionable fix + 残課題識別)
  N≥4 → 究極深層 (= 残課題殲滅 + pattern 自体を docs 化)
  検知 heuristic: 過去 session 内同文言 90%+ / 同意図 / 完了確認省略
  詳細: docs/N_TIME_ALARM_PATTERN.md
  既存軸 cross-ref: AI_FLEET_SYNERGY #1 (Strict Routing) / INDIE_DEV_VELOCITY #6 (Avoid Graveyard) / VIBE_CODING #4 (Black-Box I/O Verification)
```

---

## 既存 12 軸との関係

- **AI_FLEET_SYNERGY** (= 12 番目軸 / part 98): N-time alarm = 集合体運用の品質保証 mechanism
- **INDIE_DEV_VELOCITY #6** (Avoid Side-Project Graveyard): 表面対応の繰り返し = graveyard pattern / N-time alarm でこれを破る
- **VIBE_CODING #4** (Black-Box I/O Verification): User 要望 = blackbox input / N 回要望 = output が user expectation と乖離 signal
- **PHILOSOPHY #6** (資本=時間): 表面対応 N 回 = N 倍の時間損失 / depth-first で時間効率最大化

---

## なぜ rule 化するか (= meta 哲学)

ベテラン人間 PM は「同じ問い合わせ 3 回来たら issue tracker 体制を疑う」という暗黙知を持つ. これを **AI fleet で再現可能な rule** に明文化することで、新規 instance が起動した際にも **同じ判断品質** を再現できる.

= **「暗黙知の rule 化」** = SECOND_BRAIN #6 (Mega-Prompt 生成基盤) dogfood.

---

*Win版#132 part 102 / 2026-04-30 / N-time alarm pattern 文書化 / Phase 1-4 escalation / 12 軸 cross-ref / 究極深層 phase 完了*
