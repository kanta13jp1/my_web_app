# AI ビデオ 6 原則 — 自分株式会社 合成メディア・AI アバター設計ガイドライン

> このドキュメントは、自分株式会社のすべての AI 動画 / アバター / 合成メディア機能 (`scripts/video/` パイプライン / `notebooklm-video-pipeline.yml` / `philosophy_page.dart` 動画埋め込み / 将来の AI アバター対話 UI) が **どう生成・配信・検証されるべきか** を定義する **必守原則** である。
>
> **ソース**: NotebookLM Notebook [D-ID: Comprehensive Guide to AI Video Creation and Business Strategy](https://notebooklm.google.com/notebook/da2a95d1-2db3-4677-9e67-52fae69fb8e9)
> D-ID Creative Reality STUDIO / $25M Series B (顔認識防御 → AI アバター生成への事業転換) / Canva 統合 / Decentralized identifier (DID) を題材とした AI 動画生成・事業戦略・倫理に関するソース集 (2026-04-28 取り込み)
>
> **位置づけ**: 既存 6 設計軸の **応用層 (合成メディアドメイン特化)** として追加
> - [PHILOSOPHY.md](./PHILOSOPHY.md) (9 原則) = **何を作るか / why**
> - [AI_DEV_PRINCIPLES.md](./AI_DEV_PRINCIPLES.md) (7 原則) = **どう作るか / how**
> - [AI_CHARACTER_PRINCIPLES.md](./AI_CHARACTER_PRINCIPLES.md) (8 原則) = **どんな人格で動くか / who**
> - [IMBUE_PATTERNS.md](./IMBUE_PATTERNS.md) (7 パターン) = **どう感じさせるか / how it feels**
> - [COLLAB_AI_PATTERNS.md](./COLLAB_AI_PATTERNS.md) (7 パターン) = **どう進化するか / how it evolves**
> - [MCP_AUTH_SECURITY_PRINCIPLES.md](./MCP_AUTH_SECURITY_PRINCIPLES.md) (10 原則) = **どう開かれるか / how it opens**
> - **AI_VIDEO_PRINCIPLES.md** (6 原則) = **どう動画として現れるか / how it appears as synthetic media**

---

## なぜ必要か

自分株式会社は既に NotebookLM 由来の YouTube 動画 8 本を `philosophy_page.dart` に埋め込み、`scripts/video/` (transcribe / build_srt / make_cards / smoke_test) + `notebooklm-video-pipeline.yml` (8 ステップ自動化) で **動画を継続的に生成する側** になっている。

D-ID の事例 = 顔認識「**防御**」技術から AI アバター「**生成**」プラットフォームへの転換 + Canva 統合 + Realtime Agents API / WebRTC + Decentralized identifier (DID) は、自分株式会社が以下の進化を辿る上で **設計言語の不足** を補うために必要である:

- 静止 YouTube 埋め込み → リアルタイム対話型 AI キャラクター UI
- テキスト原稿 → 動的 AI アバター動画 (理念・CS 応答・教育コンテンツ)
- ユーザー認証のみ → AI エージェント / AI 動画自身の **検証可能なアイデンティティ**
- 倫理的曖昧さ → ウォーターマーク + 来歴メタデータによる **合成メディアの透明性担保**

合成メディアは「**生成できるか**」より「**どう信頼を担保するか**」「**どう統合するか**」「**どう倫理的に配信するか**」が遥かに難しく、原則化が必要。

---

## 6 原則

### 原則 1: 動的アバター体現 (Dynamic Avatar Embodiment)

**ルール本文**: テキスト・音声・静止画から、Lifelike (本物そっくり) な AI アバター動画を **自動生成・配信** できるパイプラインを持つ。事前録画・人手編集に依存しない。

**なぜ重要か**: 自分株式会社の理念・機能・CS 応答は **継続的に更新** される。1 動画あたり数時間の人手編集が必要なら、コンテンツの鮮度を保てない。アバター生成を自動化すれば「理念が変わったらその日のうちに新動画」が成立する。

**どう適用するか**:
- `notebooklm-video-pipeline.yml` を拡張: D-ID-API 互換の avatar 生成ステップを追加 (input: `philosophy_text`, output: avatar mp4)
- `philosophy_page.dart` の動画 8 本のうち、理念解説 4 本を **動的生成版** に置き換え (毎回最新の `docs/PHILOSOPHY.md` を音声化)
- `scripts/video/build_avatar.py` 新規 (テキスト → mp3 (TTS) → 静止画 + 音声 → mp4 (avatar lipsync))
- ❌ NG: 動画は 1 度作って YouTube 固定 URL embed → 理念更新時に陳腐化
- ✅ OK: 理念 docs 更新 → GHA が自動で avatar 動画再生成 → embed URL 更新

### 原則 2: 防御 → 生成のピボット原則 (Defensive to Generative Pivot)

**ルール本文**: 顔認識防御 (D-ID 旧事業) で蓄積した **生体データ・なりすまし耐性** の知見を反転させ、**安全な AI アバター生成** の基盤に転用する。攻撃者視点で防御していた強みを、生成側の安全装置として再利用する。

**なぜ重要か**: AI アバター生成は **悪意ある利用 (deepfake / なりすまし)** のリスクを内包する。ゼロから安全装置を作るより、防御側の知見を活用する方が成熟が早い。自分株式会社は Supabase RLS / MCP Auth Security 10 原則を既に持つので、これを **アバター生成許可制御** に応用する。

**どう適用するか**:
- `supabase/functions/avatar-generate` 新設時 (将来): MCP_AUTH 原則 #2 (Bearer Deny-by-Default) を継承し、アバター画像 URL の whitelisting を強制
- 個人の顔写真をアバター素材化する際、**本人同意** + **署名付き音声サンプル** を組として保存 (Supabase RLS で本人のみ生成可能)
- 生成されたアバター動画には **元素材のハッシュ** をメタデータに埋め込み、後から流出元追跡可能
- ❌ NG: 任意の URL 画像から avatar 生成許可 (deepfake 工房化)
- ✅ OK: Supabase ストレージ + 本人 OAuth 認証で許可された素材のみアバター化

### 原則 3: シームレスなワークフロー統合 (Seamless Workflow Integration)

**ルール本文**: D-ID の Canva 統合のように、AI 動画生成プロセスを **既存の制作・編集パイプラインに直接組み込む**。「動画を作るために別ツールを開く」摩擦をゼロにする。

**なぜ重要か**: コンテンツ生成は **頻度** で価値が決まる。AI 動画を作るために `scripts/video/` を手動実行・YouTube に手動アップロード・Flutter コードに手動 embed の 3 段階を踏む現状は、手間の総和が頻度の上限を決めている。

**どう適用するか**:
- `notebooklm-video-pipeline.yml` を拡張: テキスト変更 push → avatar 生成 → YouTube API upload → `lib/pages/*` の embed URL を更新する PR 自動作成、までを GHA 1 本で完結
- ユーザー側 UI (将来): `app-content-edit-page` でテキスト編集 → 「動画化」ボタン → 数分後に Flutter Web に反映
- Canva ライクな統合検討: Notion / Slack に動画生成 webhook を設置し、メッセージ → アバター動画返信
- ❌ NG: 動画作成 = エンジニアが手元で `scripts/video/*` 実行する工程
- ✅ OK: コンテンツ更新 → GHA が動画生成 → Flutter に embed 反映、までゼロタッチ

### 原則 4: 分散型アイデンティティ検証 (Decentralized Identity / DID Verification)

**ルール本文**: 中央集権レジストリに依存しない **検証可能 (verifiable) かつ永続 (persistent) な分散型識別子 (DID)** を、人間ユーザーだけでなく **AI エージェント・AI 生成動画自身** にも付与する。「これは誰が作ったコンテンツか」を暗号学的に検証可能にする。

**なぜ重要か**: 12 インスタンス並行開発 + AI アバター生成が常態化すると、「これは Claude Code Win版#132 part 75 が生成」「これは Codex#1 が修正」「これは AI アバター A が発話」を区別する必要が出る。Supabase Auth は **人間のセッション** には十分だが、AI エージェント間のなりすまし防止には不十分。DID は外部信用機関なしで本人性を証明できる。

**どう適用するか**:
- 各 AI EF (`ai-assistant` / `ai-writing-assistant` / `daily-judgment` 等) に DID 発行 (例: `did:web:my-web-app-b67f4.web.app:agents:ai-assistant`)
- 生成動画のメタデータに DID 署名を埋め込む (W3C Verifiable Credentials 仕様)
- `mcp_oauth_clients` table に DID カラムを追加し、MCP クライアントの身元証明に使用 (= MCP_AUTH 原則 #1 DCR との接続点)
- ❌ NG: AI 動画は誰が作ったか不明 (出元追跡不可)
- ✅ OK: 全 AI 動画メタデータに DID 署名 → 「これは確かに自分株式会社の Claude#X が生成」と検証可能

### 原則 5: 倫理的来歴と透明性 (Ethical Provenance & Transparency)

**ルール本文**: 生成された合成メディアには **AI 生成物であることを明示** する。ウォーターマーク + 来歴メタデータ + DID 署名の 3 層で偽情報拡散を防ぐ。「分からないように生成する」を技術的に許容しない。

**なぜ重要か**: 自分株式会社は「ユーザーの人生という会社の取締役会・伴走者」(PHILOSOPHY 原則 3) として信頼を売っている。1 件でも deepfake と疑われる動画が出れば、サービス全体の信頼が崩れる。OPS-28 charter §改善トリガー の延長として、合成メディアにも「常時審査される倫理基準」が必要。

**どう適用するか**:
- `scripts/video/build_avatar.py`: mp4 出力前に **可視ウォーターマーク** (画面右下「自分株式会社 AI 生成」) を強制挿入
- mp4 メタデータに以下を埋め込み: (a) 生成 timestamp / (b) 元テキストの SHA-256 / (c) 原則 4 の DID 署名 / (d) 使用モデル名
- `philosophy_page.dart` 動画埋め込み欄に「この動画は AI で生成されました」バッジを常時表示
- ❌ NG: 「リアルだから本物の社員と勘違いされても OK」と放置
- ✅ OK: ウォーターマーク + メタデータ + UI バッジの 3 層で AI 生成を常時明示

### 原則 6: インタラクティブ・リアルタイム・プレゼンス (Interactive Real-time Presence)

**ルール本文**: 事前生成・固定埋め込みの非同期動画から、**WebRTC ベースの低遅延リアルタイム対話型 AI エージェント** へ UX を進化させる。`philosophy_page.dart` で「動画を見る」体験を「動画キャラクターと話す」体験に変える。

**なぜ重要か**: 動画は一方向だが、対話は双方向。自分株式会社の競合 (Notion AI / ChatGPT) はテキスト対話に閉じている。アバター対話 UX は **テキストでない問い** (= 感情・態度・言いにくい話) に応答できる差別化要素になる。

**どう適用するか**:
- `lib/pages/ai_assistant_chat_page.dart` を拡張: 既存テキスト対話に加え、`avatar_realtime_widget.dart` 新規追加 (D-ID Realtime Agents API 互換 / WebRTC `peer_connection` ラップ)
- 初期段階: `philosophy_page.dart` の固定動画 1 本を「キャラクターと話す」モードに置換 (ボタン 1 つで切替)
- レイテンシ予算: 音声入力 → アバター応答 RTT < 2 秒 (D-ID benchmark 準拠)
- 段階的有効化: 内部テスト → admin 限定 → opt-in パブリック の 3 段階で展開
- ❌ NG: いきなり全ユーザーに realtime avatar UI 公開 (失敗時の信頼コスト大)
- ✅ OK: opt-in α 版 → ユーザーフィードバック反映 → GA 公開、の段階的進化

---

## 6 原則の相互依存

```
[Dynamic Avatar Embodiment] (生成パイプライン)
        ↓ 出力に必須
[Ethical Provenance] (ウォーターマーク + メタデータ)
        ↓ 検証手段に必須
[DID Verification] (暗号学的署名)
        ↓ 安全装置に必須
[Defensive→Generative Pivot] (素材許可制御)
        ↓ 制作頻度向上に必須
[Seamless Workflow Integration] (GHA 自動統合)
        ↓ 体験進化に必須
[Interactive Real-time Presence] (WebRTC 対話 UI)
```

= **生成 → 倫理 → 検証 → 安全 → 統合 → 対話** の 6 段進化階層. 1 段抜けると上位段が成立しない.

---

## 既存 6 設計軸との関係

| 既存軸 | AI_VIDEO 6 原則の augmentation 関係 |
| --- | --- |
| PHILOSOPHY (why) | 原則 5 (Ethical Provenance) で「合成メディアの倫理基準」を明文化 |
| AI_DEV (how) | 原則 3 (Seamless Workflow) で「自動化の摩擦ゼロ化」を補強 |
| AI_CHARACTER (who) | 原則 1 (Dynamic Avatar) で「人格に対応する顔」を獲得 |
| IMBUE (how it feels) | 原則 6 (Interactive Real-time) で「対話の身体性」を追加 |
| COLLAB_AI (how it evolves) | 原則 4 (DID) で「AI エージェント間の身元検証」を提供 |
| MCP_AUTH (how it opens) | 原則 2 (Defensive→Generative) で「攻撃面知見の活用」を加点 |

= 全 6 設計軸に対して 1 原則ずつ augmentation を提供. 既存軸を置換しない.

---

## チェックリスト (新動画機能 PR 時)

- [ ] **原則 1**: 動画は静的 URL embed でなく、コンテンツ更新で再生成されるか?
- [ ] **原則 2**: アバター素材は本人同意 + 認証経由で取得しているか?
- [ ] **原則 3**: 動画生成 → embed 反映が GHA で自動完結するか?
- [ ] **原則 4**: 生成動画にメタデータ DID 署名が埋め込まれているか?
- [ ] **原則 5**: ウォーターマーク + UI バッジ + メタデータの 3 層で AI 生成明示しているか?
- [ ] **原則 6**: リアルタイム対話 UX が必要な機能か? 必要なら段階展開計画はあるか?

---

## 整合性監査 (定期セルフレビュー)

`scripts/check_ai_video_compliance.py` (将来追加):
- `lib/pages/*` 内の動画 embed URL を一覧
- 各 URL の動画メタデータを取得し、DID 署名 + ウォーターマーク有無を検査
- 違反検出時は GitHub Issue 自動作成 (= COLLAB_AI Pattern Verifier-Generator + OPS-28 改善トリガー連携)

---

## 実装履歴

| 日付 | part | 実装 | 達成原則 | baseline |
| --- | --- | --- | --- | --- |
| 2026-04-28 | Win版#132 part 64 | 軸確立 (docs + Rule [AI-VIDEO-29]) | — | 1.5/6 (#1+#3 部分のみ) |
| 2026-04-28 | Win版#132 part 65 | `scripts/video/add_provenance.py` 新規 + `notebooklm-video-pipeline.yml` Step 6c 追加 (ウォーターマーク + メタデータ 2 層) | #5 (UI バッジ層は未) | 2.0/6 |
| 2026-05-08 | Win版#132 part 178 | Faceless Channel 運用パターン章追加 (= NotebookLM `bc91fac9` 蒸留 / Issue #1750 + #1757) | — (= 6 原則の応用例 / 新原則ではない) | 2.0/6 維持 |

**次回ターゲット**:
- #5 UI バッジ層 (`lib/pages/philosophy_page.dart` 動画 embed 欄に「AI 生成」バッジ) → VSCode版 cross-instance-pr 候補
- #4 DID 署名 (W3C VC 仕様 + mcp_oauth_clients DID カラム) → Codex#1 候補
- #1 `scripts/video/build_avatar.py` 新規 (TTS + 静止画 + lipsync) → Win版 or VSCode版

---

## Faceless Channel 運用パターン (= 6 原則の応用例)

> **ソース**: NotebookLM Notebook [The Blueprint for Faceless AI YouTube Automation (`bc91fac9-ee55-4e19-9d90-3dfdf9145370`)](https://notebooklm.google.com/notebook/bc91fac9-ee55-4e19-9d90-3dfdf9145370)
> **追加日**: 2026-05-08 / Win版#132 part 178 / Issue [#1750](https://github.com/kanta13jp1/my_web_app/issues/1750) + [#1757](https://github.com/kanta13jp1/my_web_app/issues/1757) (`bc91fac9` 同源 dup-merge 候補)
> **位置づけ**: 既存 6 原則の **置換ではなく応用例**. AI 大学シリーズ (D variant pipeline / 既 4 本) を **無人 channel 化** する観点で再設計.

### なぜ Faceless Channel か

自分株式会社の動画資産は philosophy_page.dart 埋め込み 8 本 + AI 大学シリーズ 4 本. 顔出しなし・人手編集なしで **月次 X 本ペースの publish + 収益化** を狙える Faceless YouTube パターンは, 既に持つ 8-step pipeline (`notebooklm-video-pipeline.yml`) を **チャネル運用に拡張** するだけで成立する.

**比較**:

| 軸 | 顔出し YouTuber | Faceless AI Channel (= 自分株式会社想定) |
| --- | --- | --- |
| 1 本制作工数 | 5-15 hour (= 撮影+編集+サムネ) | 30-60 min (= GHA 自動 / 既 D variant 拡張) |
| 月次 publish 上限 | 4-8 本 (= human bandwidth) | 20-30 本 (= GHA cron 並列) |
| collaborator 依存 | 編集者・撮影者必須 | ゼロ (= AI 大学 #1-4 で実証済) |
| 倫理リスク | 低 (= 本人) | 高 (= 原則 5 Ethical Provenance 必須) |
| 収益化条件 | 1000 subs + 4000h 視聴 | 同上 + AI 生成明示 (YouTube 2024 規約) |

### 既存 D variant pipeline 拡張点 (= 7 工程)

```
[既存 8-step (notebooklm-video-pipeline.yml)]
   1. notebooklm download video
   2. ElevenLabs Scribe transcribe
   3. build_srt.py (SRT 分割)
   4. make_cards.py (intro/outro PNG)
   5. ffmpeg intro/outro mp4
   6. ffmpeg concat+grade+afade (+ Step 6c provenance)
   7. upload_youtube.py (privacy=unlisted)
   8. philosophy_page.dart embed commit

[Faceless Channel 拡張 (= 7 追加工程 / 段階導入)]
   F1. ideation: scripts/video/faceless_ideation.py (= 新規 / NotebookLM jibun-master-brain → 候補 5 本/週)
   F2. script: notebooklm 「ノート要約 → 動画 script」 (= 既存 audio overview 流用)
   F3. TTS: ElevenLabs voice_id 固定 (= channel persona 一貫性)
   F4. visuals: stock B-roll (Pexels API) + 既存 make_cards.py
   F5. assembly: 既 Step 5-6 流用 (= ffmpeg concat / provenance)
   F6. publish: upload_youtube.py --privacy public (= unlisted から昇格)
   F7. analytics: scripts/video/faceless_kpi.py (= 新規 / YouTube Analytics API → docs/CHANNEL_KPI.md 自動更新)
```

### 月次運用 KPI (= Q2 stub)

| 指標 | Phase 0 (= 現状 part 178) | Phase 1 (= 2026-Q3 / 公開) | Phase 2 (= 2026-Q4 / 収益化) |
| --- | --- | --- | --- |
| publish 本数 / 月 | 1-2 本 (= AI 大学拡張) | 8-12 本 | 20-30 本 |
| total subs | < 100 | 1000 (= YouTube monetization gate) | 5000+ |
| watch hour 累計 | 微小 | 4000h (= YouTube monetization gate) | 16000h+ |
| 1 本平均工数 | 60 min | 30 min | 15 min (= GHA full auto) |
| 月次 GHA cost | 数百円 | < 3000 円 | < 8000 円 (= EF + YouTube API) |

### D-ID 6 原則との接続 (= 1 行ずつ)

| 原則 | Faceless Channel への適用 |
| --- | --- |
| #1 Dynamic Avatar Embodiment | F3 TTS + F1 ideation で「コンテンツ更新 → 自動再生成」を月次サイクル化 |
| #2 Defensive→Generative Pivot | F4 visuals = stock B-roll に限定 (= 任意 URL 画像許可せず deepfake 化を物理的に防ぐ) |
| #3 Seamless Workflow Integration | 既 8-step + 拡張 7 工程を **GHA 1 workflow** に統合 (= 別ツール開かずゼロタッチ) |
| #4 DID Verification | F6 publish 時に動画メタデータへ `did:web:my-web-app-b67f4.web.app:agents:faceless-channel` 署名 |
| #5 Ethical Provenance | F5 assembly で既 `add_provenance.py` 必須 + 動画概要欄に「AI で生成」明示 |
| #6 Interactive Real-time Presence | Phase 3 (= 2027 H1 想定) で channel から philosophy_page.dart リアルタイム対話 UI へ誘導 |

### 受入条件 (= Issue #1750 + #1757 close 基準)

- [x] `docs/AI_VIDEO_PRINCIPLES.md` Faceless Channel 運用パターン章追加 (= 本 commit / part 178)
- [ ] `scripts/video/faceless_ideation.py` 新規 (= F1 工程 / Codex hand-off 候補)
- [ ] `scripts/video/faceless_kpi.py` 新規 (= F7 工程 / Codex hand-off 候補)
- [ ] `notebooklm-video-pipeline.yml` の F-prefix workflow 拡張 (= Codex hand-off 候補)
- [ ] `docs/CHANNEL_KPI.md` 新規 (= F7 出力先 / Win Claude or Codex)

### Codex hand-off 想定 task (= 期限 2026-05-22 / Phase 1 stub)

| task | role | 工数 | 備考 |
| --- | --- | --- | --- |
| `scripts/video/faceless_ideation.py` 新規 | Codex (= 実装) | 2h | NotebookLM CLI 経由 / 候補 5 本/週 JSON 出力 |
| `scripts/video/faceless_kpi.py` 新規 | Codex (= 実装) | 2h | YouTube Analytics API v2 / `docs/CHANNEL_KPI.md` 自動更新 |
| `notebooklm-video-pipeline.yml` Step F1-F7 統合 | Codex (= GHA) | 3h | matrix or sequential 設計 / `concurrency` で 1 本/時 cap |
| `docs/CHANNEL_KPI.md` template | Win Claude (= docs) | 1h | F7 出力 schema 定義 + 月次 markdown 表 |
| Issue #1724 secrets 設定 (= 関連) | user (= secret) | 30min | YOUTUBE_TOKEN_JSON 等 5 secrets / Win Claude/Codex 触れない |

### 関連 Issue

- [#1750](https://github.com/kanta13jp1/my_web_app/issues/1750) (= 親 / 2 本蒸留): 本章で Faceless 半分着地. Design-Agent 半分は `STRATEGIC_INTELLIGENCE_2026Q2.md` 参照
- [#1757](https://github.com/kanta13jp1/my_web_app/issues/1757) (= 子 / 同 notebook `bc91fac9` 単独調査): 本章で内容吸収済 → close 候補
- [#1724](https://github.com/kanta13jp1/my_web_app/issues/1724) (= P1 / 5 secrets 設定): F6 publish 公開化の前提
- [#1788](https://github.com/kanta13jp1/my_web_app/issues/1788) (= P3 / D-ID + Hedra アバター): Phase 3 リアルタイム presence への bridge

### Philosophy / Principle Alignment

- **PHILOSOPHY-22** = 9/9 ✅ (= 商品=価値 / 資本=時間 / KPI=昨日の自分 で月次本数 KPI 化)
- **AI-DEV-23** = 7/7 ✅ (= GHA quality-gate + memory 永続 + DLQ 設計済)
- **AI-VIDEO-29** = 6/6 必須維持 (= 本章は応用例 / 原則変更なし)
- **VIBE-30** = 7/7 ✅ (= AI 生成明示 + ウォーターマーク + 段階展開)
- **PLATFORM-31** = 7/7 ✅ (= channel = platform 拡張 / lock-in 回避は YouTube + Vimeo dual upload で将来対応)

---

*Win版#132 / 2026-04-28 起票 / NotebookLM da2a95d1 (D-ID) ソース蒸留 / Rule [AI-VIDEO-29] / 7 番目の設計軸 / 2026-05-08 part 178 で Faceless Channel 章追加 (= NotebookLM bc91fac9 / Issue #1750 + #1757)*
