-- Session PS#3-S24: AI大学 142 社化 — Isomorphic Labs 追加
-- Demis Hassabis (Nobel 2024) + John Jumper 率いる Alphabet の drug discovery ラボ
-- AlphaFold 3 (2024-05, Nature) + IsoDDE (2026-02-10) が主力。
-- Eli Lilly $1.75B + Novartis $1.2B ($37.5M 先行金) 合計 $3B deal / 追加 $600M 直接投資
-- 既存 141 社に完全空白だった biology / drug discovery 軸を埋める。
-- Step 0: 8/9 (API=公共 server 限定 / OSS=AF3 学術限定で一部 0.5 減点)

INSERT INTO ai_university_content (provider, category, title, content, updated_at)
VALUES
  (
    'isomorphic_labs',
    'overview',
    'Isomorphic Labs — AlphaFold 3 + IsoDDE で新薬を設計する Alphabet ラボ',
    $md$
# Isomorphic Labs — AlphaFold 3 + IsoDDE で新薬を設計する Alphabet ラボ

2021 年創業 (Alphabet の DeepMind spinout)。CEO **Demis Hassabis** と
チーフサイエンティスト **John Jumper** が 2024 年 **ノーベル化学賞** を受賞
(AlphaFold の貢献)。「AI で drug discovery を根本から再発明する」ことを
ミッションに、protein 構造予測 + ligand 設計 + antibody 界面予測を 1 つの
engine に統合する biology AI foundation model ラボ。

## 既存 141 社との差別化
| 観点 | Isomorphic Labs | Recursion Pharmaceuticals | Xaira Therapeutics |
|------|-----------------|---------------------------|--------------------|
| レイヤー | 🧬 **structure-first foundation model** | cell image phenomics | LLM-for-biology |
| 親会社 | Alphabet (non-公開子会社) | NASDAQ:RXRX 上場 | private |
| 主力 | AlphaFold 3 / IsoDDE | Phenomap + MolRec | Xaira Protein Design |
| 公開度 | AlphaFold Server (無料 / 学術) | 論文 + 一部 dataset | closed |
| 主要顧客 | Eli Lilly + Novartis (自社パイプラインも保有) | Roche / Genentech | 自社創薬 |
| 哲学 | 「protein は分子の世界の GPT」 | cell 画像の foundation model | LLM + RL で de novo 分子 |

## 主要モデル
- **AlphaFold 3** (2024-05, Nature 誌): protein 単独ではなく **DNA/RNA/リガンド/
  イオン** を含む任意の生体分子複合体構造を予測。AlphaFold 2 比で精度大幅向上。
- **IsoDDE** (2026-02-10, 技術報告): unified drug design engine。AF3 比 2 倍の
  protein-ligand 予測精度を benchmark で達成 (社内 report)。4 機能: 構造予測 +
  抗体抗原界面モデリング + 結合親和性推定 + リガンド化ポケット同定。

## 提携
- **Eli Lilly** (2024-01): **\$45M 先行金 + \$1.75B マイルストーン** / 低分子新薬
- **Novartis** (2024-01 + 2025-02 拡張): **\$37.5M 先行金 + \$1.2B** / 3 target
  → 拡張で追加 3 research program
- 2026-01 時点で事業価値合計 **\$3B 超**、複数の preclinical candidate 段階

## 資金 & 組織
- Alphabet 直接出資 + 追加 **\$600M+ 外部 funding** ラウンド
- 社員数 数百人規模 (London HQ)
- Demis Hassabis は DeepMind CEO 兼任

## 自分株式会社での活用
- daily-judgment: AlphaFold Server で興味のある protein 構造を可視化→
  docs/PHILOSOPHY.md 原則 5「商品=ユーザー価値」の raw 材料に
- AI大学: biology 軸が完全空白 → 第 12 カテゴリ (biology/drug discovery) 候補
- user-manual: 論文 "Accurate structure prediction of biomolecular interactions
  with AlphaFold 3" (Nature, 2024) を日本語要約化
$md$,
    NOW()
  ),
  (
    'isomorphic_labs',
    'models',
    'AlphaFold 3 / IsoDDE — 生体分子構造予測の SOTA 2 世代',
    $md$
# AlphaFold 3 / IsoDDE — 生体分子構造予測の SOTA 2 世代

## AlphaFold 3 (2024-05)
- Nature 誌で発表 ("Accurate structure prediction of biomolecular interactions
  with AlphaFold 3")
- AF2 は **protein のみ**→ AF3 は **protein + DNA + RNA + リガンド +
  イオン + 修飾** の任意の複合体を予測
- diffusion-style generation head (旧 Evoformer から進化)
- **CASP** 相当の内部 benchmark で AF2 + 既存 docking tool を上回る精度
- **weights + code**: 2024-11 に学術用途で公開 (商用利用は不可)
- 使い方: https://alphafoldserver.com/ で sequence を貼るだけ

## IsoDDE (2026-02-10)
- 4 機能を 1 つの engine に統合:
  1. protein-ligand 構造予測
  2. 抗体抗原界面モデリング
  3. 結合親和性推定 (affinity)
  4. リガンド化ポケット同定
- benchmark: AF3 比 **2 倍の精度** (protein-ligand 汎化ベンチマーク)
- 公開度: **proprietary** — code/weights/API/査読論文なし (社内 report のみ)
- 「AF3 から drug design 専用に pivot」した位置付け

## Alphabet との関係
- Google DeepMind が親チームを保有 (AlphaFold 系列は DeepMind 発)
- Isomorphic が商用 drug discovery ビジネスを担当
- GPU インフラは Google Cloud (TPU 学習)

## ライセンス
- AlphaFold 2: Apache 2.0 (code) / CC BY 4.0 (weights)
- AlphaFold 3: 学術 non-commercial license (code + weights / 2024-11 公開)
- IsoDDE: closed

## Philosophy (Hassabis 公言)
> "AlphaFold は始まりに過ぎない。protein の世界の GPT を作り、
>  それを drug discovery に applied して、10 年後には 1 病気 1 週間で
>  候補分子を出す時代を作る。"
$md$,
    NOW()
  ),
  (
    'isomorphic_labs',
    'api',
    'AlphaFold Server — 自分株式会社での利用手順',
    $md$
# AlphaFold Server — 自分株式会社での利用手順

## AlphaFold Server (無料 / 学術用途)
- https://alphafoldserver.com/ — Google アカウントでログイン
- 1 日の job 数に上限 (研究目的を想定)
- sequence (protein / DNA / RNA / リガンド SMILES) を貼るだけで 3D 構造出力
- 結果は PDB / CIF / mmCIF で download 可

## AlphaFold 3 学術コード (2024-11 公開)
```bash
git clone https://github.com/google-deepmind/alphafold3
cd alphafold3
pip install -e .
# weights は request form 経由で取得 (学術限定)
```

## AlphaFold 2 (Apache 2.0 / 商用可)
```bash
pip install alphafold  # or DeepMind 公式 repo
# ColabFold wrapper が簡便: https://github.com/sokrypton/ColabFold
```

## IsoDDE
- **API なし / weights なし / 商用 license なし** (2026-04 時点)
- Isomorphic の drug discovery サービス経由のみアクセス可
- 提携: Eli Lilly / Novartis (独占的に利用)

## 自分株式会社での組込方針
```typescript
// supabase/functions/ai-hub/index.ts に追加
// ※ biology / drug discovery 用途は個人 well-being との距離遠いため慎重運用
case 'biology.protein_structure':
  // AlphaFold Server に sequence を貼り付け→構造 JSON を返却
  // simulation 用途 (education / 自分健康情報理解) のみ使用 — AI-DEV-23 原則 2 (deny-by-default)
  return await alphafoldServerQuery(body);
```

## 試す
- Web: https://alphafoldserver.com/
- 公式: https://www.isomorphiclabs.com/
- 論文 (AlphaFold 3): Nature 2024 / DOI 10.1038/s41586-024-07487-w
- Google Blog: https://blog.google/technology/ai/google-deepmind-isomorphic-alphafold-3-ai-model/
- IsoDDE 解説: https://www.isomorphiclabs.com/articles/the-isomorphic-labs-drug-design-engine-unlocks-a-new-frontier

## 想定コラボ
- Physical Intelligence (S23) との補完: 「物理世界 = robot」 vs 「分子世界 = AF3」
  の foundation model 対比で第 11-12 カテゴリの骨格を形成
- Goodfire (S12) との補完: interpretability × biology foundation model で
  「AF3 が何を見て結合を予測しているか」の解釈可能性研究
$md$,
    NOW()
  )
ON CONFLICT (provider, category) DO UPDATE
SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
