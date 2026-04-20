-- Session PS#3-S27: AI大学 144 社化 — Figure AI 追加
-- Brett Adcock (Archer Aviation / Vettery 創業) 率いる humanoid robot スタートアップ。
-- 2022 創業 → Figure 01 (2022) / Figure 02 (2024-08) / Helix VLA (2025-02) / Figure 03 (2025-10)。
-- 2025-09 Series C $1B+ @ $39B valuation (累計 $1.9B / NVIDIA・Microsoft・Bezos・Parkway)。
-- 2025 年 OpenAI partnership 終了 → Helix VLA 自社開発に完全 pivot。
-- BMW Spartanburg で Figure 02 稼働 (11 ヶ月 / 10h shift / 90,000+ parts / 30,000+ X3)。
-- BotQ 工場 (2025-03 launch): 現 12,000 robot/年 → 目標 50,000/年 → 4 年で 100,000 robot。
-- 既存 143 社に空白だった「humanoid (embodied AI) + 自社 foundation VLA + 自社製造」軸を埋める。
-- Step 0: 8/9 (OSS=0 / API=一般未公開だが BMW + White House deploy で実証 9 相当)

INSERT INTO ai_university_content (provider, category, title, content, updated_at)
VALUES
  (
    'figure_ai',
    'overview',
    'Figure AI — Brett Adcock が率いる humanoid robot + Helix VLA 自社垂直統合',
    $md$
# Figure AI — Brett Adcock が率いる humanoid robot + Helix VLA 自社垂直統合

2022 年 Sunnyvale 創業。CEO **Brett Adcock** (Archer Aviation 共同創業・Vettery 創業・
Cisco 買収 exit) が率いる「汎用 humanoid robot + 自社 VLA foundation model + 自社製造」
の三位一体 embodied AI スタートアップ。2024-08 Figure 02 → 2025-02 Helix VLA 自社発表 →
2025-10 Figure 03 の 3 世代で「OpenAI 依存 ZERO の自社 stack」に転換した。

## 既存 143 社との差別化
| 観点 | Figure AI | Physical Intelligence (S23) | Tesla Optimus |
|------|-----------|-----------------------------|----------------|
| レイヤー | 🦾 **humanoid 本体 + VLA + 工場** 全スタック | VLA foundation model (π-0 OSS) | 自動車統合 humanoid |
| 本体設計 | Figure 01/02/03 (最新: 03) 自社設計製造 | 本体なし (VLA model 提供) | Optimus Gen 2 自社設計 |
| Foundation AI | **Helix VLA 自社 in-house** (OpenAI 依存終了) | π-0 / π-0.5 OSS (Apache 2.0) | FSD 派生自社開発 |
| 生産能力 | BotQ 工場 12K/年 → 50K/年目標 | 研究段階 (製造なし) | 2026 生産目標数千台 |
| 投資家 | NVIDIA / Microsoft / Bezos / Parkway | Bezos / OpenAI / CapitalG | Tesla 内製 |
| Valuation | **$39B** (2025-09) | $11B (交渉中) | N/A (Tesla 連結) |

## 主要世代 — Figure 01 → 03 の 3 世代 (2022 → 2025)
- **Figure 01** (2022-10 プロトタイプ / 2023 公開) — 5'6" 60kg の humanoid プロトタイプ。
  初期は OpenAI partnership で音声対話デモ (コーヒー差し入れ動画など)
- **Figure 02** (2024-08 launch) — 商用 generation。BMW Spartanburg で 11 ヶ月稼働し
  90,000+ 部品を搬送 / 30,000+ X3 車両生産に貢献 / 10h shift 耐久実証
- **Figure 03** (2025-10-09 発表) — 4x 小型化 SoC / 2x battery 効率 / 5x audio bandwidth /
  コストは Figure 02 比 **90% 減** / White House 公式 debut / BotQ 量産化第 1 世代
- **Helix VLA** (2025-02 発表) — Vision-Language-Action model 自社開発。35 DoF (上半身 +
  ハンド) / latency < 200ms / 音声指示 → 動作 end-to-end / 2025 OpenAI partnership 終了

## 業績 (2026-Q1 推計 / 非公開のため公開情報集約)
- **年産 12,000 robot** (BotQ 工場現時点 capacity)
- **目標 50,000 robot/年** (2026 full ramp 時)
- **4 年で 100,000 robot + 3M actuator** 供給チェーン確約 (White House 発表)
- 顧客 revenue は非公開 (BMW + UPS 伝聞 + 未発表 logistics 顧客)
- Figure 03 コスト構造は 02 比 **90% 減** (量産 scale + 自社設計 actuator)

## 資金調達
- 2024-02 Series B: **$675M @ $2.6B valuation** (Microsoft / NVIDIA / Bezos / OpenAI 他)
- 2025-09 Series C: **$1B+ @ $39B valuation** (Parkway Venture Capital 主導)
- 累計 **$1.9B** / 2024→2025 で valuation **15 倍** (2.6B → 39B)
- 投資家 mix: Bezos Expeditions / NVIDIA / Microsoft / Intel Capital / Parkway / Align Ventures

## 提携・deploy 実績
- **BMW Spartanburg 工場** (2024-08 〜): Figure 02 が 11 ヶ月稼働 /
  90,000+ 部品ピッキング + 搬送 / 30,000+ X3 SUV 生産ライン貢献 / 10h shift x 5 days
- **UPS** (噂・公式未発表): logistics deploy 検討中との報道
- **White House** (2025-10-09): Figure 03 debut + 100,000 robot + 3M actuator
  4 年供給確約 → 米国製造業 re-shoring policy の flagship
- **BotQ 製造施設** (Sunnyvale / 2025-03 open): 自社 humanoid 専用量産 line

## 自分株式会社での活用
- daily-judgment: Figure の「OpenAI 依存終了 → Helix 自社化」思想は、自分株式会社が
  AI-hub routing で単一 vendor lock-in を避ける設計 (docs/PHILOSOPHY.md 原則 7
  「資産負債バランスシート」= AI vendor は負債化リスク) と同じ構造
- ai-hub: Helix VLA が「音声 → 動作」end-to-end で latency 200ms 達成した事実から、
  ai-assistant の音声モード化時は Realtime API (OpenAI) vs 自社 VAD+ASR+TTS 縦割り
  の routing 方針を早期に決めておく
- AI大学: humanoid 軸 = 第 14 カテゴリ候補 (既存 embodied は Physical Intelligence 1 社・
  Figure AI 追加で 2 社 → 軸として独立化可能)
$md$,
    NOW()
  ),
  (
    'figure_ai',
    'models',
    'Helix VLA + Figure 03 — 35 DoF humanoid の vertical stack',
    $md$
# Helix VLA + Figure 03 — 35 DoF humanoid の vertical stack

## アーキテクチャ概要
Figure AI は「本体 hardware / Helix VLA brain / BotQ 工場」を全て自社で保有する
**垂直統合 embodied AI スタック**。2025 年前半まで OpenAI の foundation model を
脳として使っていたが、2025-02 に Helix VLA を発表 → OpenAI partnership を終了し
**自社 stack only に完全転換** した。

## Helix VLA (Vision-Language-Action / 2025-02 発表)
- **DoF (Degrees of Freedom) 35** (上半身 + 両手)
- **latency < 200ms** (視覚入力 → action 出力 end-to-end)
- **Vision**: 自社設計カメラ array (Figure 03 で 5x audio bandwidth 拡大 + vision 統合)
- **Language**: 音声自然言語指示 → action sequence に直接マッピング
- **Action**: 関節トルク制御 + gripper 力制御まで統合
- **訓練**: BMW Spartanburg 含む実稼働 deploy から収集した実世界データで継続学習
- **OSS**: **非公開** (Physical Intelligence の π-0 と逆の戦略)
- **API**: 一般 developer 非公開 (enterprise customer の robot に焼き込まれる形)

## Figure 03 (2025-10-09 発表)
前世代 Figure 02 からの主要改善:
- **SoC 4x 小型化** (ボディ内計算リソース効率化)
- **battery 2x 長持ち** (10h shift 標準化)
- **audio bandwidth 5x 拡大** (工場騒音下での音声指示安定化)
- **cost 90% 減** (Figure 02 比・量産 scale 効果 + 自社 actuator)
- **foot design 改良** (BotQ 量産で品質管理容易化)
- White House debut 時に 100,000 robot + 3M actuator 4 年供給確約

## BotQ 製造施設 (2025-03 open / Sunnyvale)
- **現時点 capacity: 12,000 robot/年**
- **短期目標: 50,000 robot/年** (2026 full ramp)
- **中期目標: 100,000 robot 累計** (4 年 / White House 発表)
- 自社 actuator (3M 本/4 年) / 自社 frame / 自社組立
- 米国製造業 re-shoring policy の flagship 施設

## 訓練データ pipeline
- **BMW Spartanburg deploy** (2024-08 〜): 11 ヶ月で 90,000+ 部品 interaction
- **UPS テスト** (伝聞・非公表): logistics ピッキング シナリオ
- **self-collected**: BotQ 内での組立動作自己学習
- OpenAI の RLHF pipeline 依存を完全脱却 (2025 partnership 終了)

## 対 Physical Intelligence (S23) 戦略比較
| 観点 | Figure AI (Helix VLA) | Physical Intelligence (π-0) |
|------|------------------------|------------------------------|
| OSS 戦略 | closed (本体焼込) | Apache 2.0 OSS |
| Hardware | 自社 Figure 03 | hardware agnostic |
| 収益モデル | robot 1 台売上 + maintenance | API / enterprise license |
| 適用先 | 工場 + 家庭 (長期) | 研究者 + OEM (多様 robot) |
| 投資家 | NVIDIA / Microsoft / Bezos | Bezos / OpenAI / CapitalG |

→ Figure = 「closed vertical stack」/ PI = 「open horizontal platform」の教科書的対比。
両社を AI大学 に登録することで**embodied AI 軸の open/closed 二極**が揃う。

## ライセンス / 公開度
- **Helix weights / architecture: 非公開** (blog 写真 + 論文なし)
- **Figure 03 hardware spec: 部分公開** (announce の数値のみ)
- **API: enterprise customer 限定** (一般 SDK なし)
- **研究公開**: 公式 blog + launch 動画のみ (arXiv 論文ゼロ)
$md$,
    NOW()
  ),
  (
    'figure_ai',
    'api',
    'Figure AI — enterprise 導入プロセス + 自分株式会社でのメタ活用',
    $md$
# Figure AI — enterprise 導入プロセス + 自分株式会社でのメタ活用

## アクセス方法
Figure AI は **一般 developer 向け self-serve API / SDK を公開していない**。
導入経路は以下の enterprise sales process のみ:

1. https://www.figure.ai/ から企業問い合わせ
2. Figure の solutions team が use case evaluation (工場・倉庫・家庭のどれか)
3. POC: BMW / UPS 等の既存顧客 reference deploy で動作確認
4. 本番導入: 1 台 or 複数台の契約 + annual maintenance
5. 年間単位の「robot-as-a-service」契約または outright purchase

自分株式会社 (個人単位 SaaS) は Figure AI の target 顧客外だが、
**思想・垂直統合モデル・vendor 依存終了事例**は参照価値が高い。

## 調達モデルの構造 (Sacra + TechCrunch 等推計)
- **Robot 単価**: Figure 03 で公式未開示 / Figure 02 世代で **$150K-$300K/台** 推定
- **annual maintenance**: 10-20% of robot price (業界標準)
- **custom integration fee**: $100K-$500K 相当 (BMW 等エンタープライズ初期)
- **long-term lease option**: BMW Spartanburg deploy は "contract" 表記で lease 可能性
- **outright purchase**: UPS / 一部顧客は購入型 (伝聞)

## 自分株式会社 ai-hub への応用 (参考実装)
Helix VLA 方式の「音声 → 低 latency action」を ai-assistant の音声モード設計に援用:

```typescript
// supabase/functions/ai-hub/index.ts に追加
// ※ Figure の latency < 200ms target を internal KPI に設定
case 'voice.realtime_dispatch':
  // 1. STT (deepgram / whisper routing) 即時
  // 2. intent classification + skill dispatch (haiku cost 優先)
  // 3. TTS (elevenlabs / openai) 即時
  // target: end-to-end latency < 500ms (Figure の 2.5 倍許容)
  return await handleRealtimeVoice(body);
```

## 比較 table (humanoid 分野の 2026 時点 市場構造)
| 会社 | 世代 | 価格帯 | Foundation AI | 投資家 | Valuation |
|------|------|--------|----------------|---------|------------|
| **Figure AI** | Figure 03 (2025-10) | $150K-$300K (推定) | Helix VLA 自社 | NVIDIA/MS/Bezos | **$39B** |
| Tesla Optimus | Gen 2 (2024) | 目標 $20K-$30K | FSD 派生 | Tesla 内製 | (Tesla 連結) |
| 1X Technologies | NEO (2024) | 非公開 | EVE 自社 | Sandstone / Seven Seven Six | ~$400M |
| Apptronik | Apollo (2024) | 非公開 | OpenAI 提携 | Capital Factory | ~$1B |
| Agility Robotics | Digit (2023-) | 非公開 | Cursor / 自社 | Amazon / DCVC | ~$1B |

→ Figure AI は **valuation / 投資家 mix / foundation 自社化** で 2025 年時点 humanoid
  スタートアップの明確な首位。Tesla Optimus が価格破壊で挑む構図。

## 試す (参考 resources)
- 公式: https://www.figure.ai/
- Figure 03 announce: https://www.figure.ai/news/introducing-figure-03
- Helix VLA 発表: https://www.figure.ai/news/helix
- BMW Spartanburg 実績 blog: https://www.figure.ai/news/bmw
- White House 発表: https://www.figure.ai/news/white-house-commitment
- Brett Adcock interview (Bg2 Pod / All-In 等): 検索で随時追える

## 想定コラボ
- **Physical Intelligence (S23)** との対比: closed vertical stack (Figure) vs
  open horizontal platform (PI) → 両社 seed で AI大学の embodied 軸二極化
- **Sierra (S25)** との対比: デジタル agent (Sierra = CX SaaS) vs 物理 agent (Figure)
  → 同じ「outcome-based 価値」でも bit 世界と atom 世界で分岐する対比例
- **Thinking Machines Lab (S18)** との対比: model layer (TML) vs embodied application
  → foundation → platform → application の 3 層 stack の application 層 top 事例

## OpenAI partnership 終了の教訓 (自分株式会社への示唆)
Figure は 2025 年に OpenAI との partnership を終了し Helix VLA に完全自社化した。
これは「AI vendor 単一 lock-in は lever を失う」という強い signal。
自分株式会社の ai-hub routing (anthropic / openai / google / ローカル) 設計は
この教訓を先取りしていた形で、**multi-vendor routing を維持する戦略的価値**を
Figure の事例が裏付けている。

具体的には:
- ai-hub が OpenAI 単一依存に傾いたら即 pivot (Figure = 1 年で完全切替)
- Helix のように「自社軽量モデル + 外部 foundation」の hybrid 戦略が合理的
- 契約打切コストは valuation が上がるほど下がる → 早期に multi-vendor 化推奨
$md$,
    NOW()
  )
ON CONFLICT (provider, category) DO UPDATE
SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
